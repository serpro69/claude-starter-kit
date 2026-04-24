# Kubernetes — Reliability Checklist

Applied conditionally — load when the diff contains a top-level YAML document with `kind:` of `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, or `CronJob` (see `index.md`). Focuses on what keeps these workloads available during disruption.

## Contents

- PodDisruptionBudget
- Probe semantics and interaction
- Graceful shutdown
- Anti-affinity and topology spread
- Rollout strategies
- Job and CronJob reliability

## PodDisruptionBudget

- Multi-replica workloads (`Deployment`, `StatefulSet` with `replicas: >1`) need a `PodDisruptionBudget`. Its absence is a P1 finding — voluntary disruptions (node drains, cluster upgrades) can take the whole workload down.
- `PDB` uses `minAvailable` (preferred) OR `maxUnavailable` — not both.
- `minAvailable` expressed as a percentage when replica count changes over time; as an integer when the workload has a fixed replica count.
- PDB selector matches the workload's Pod labels exactly.
- Single-replica workloads with a **blocking** PDB — `minAvailable: 1` (or equivalently `maxUnavailable: 0`) — prevent node drain entirely and can deadlock cluster upgrades. **This is a P0 finding.** A PDB with `maxUnavailable: 1` on a single-replica workload is non-blocking (drain is permitted because the "max unavailable" budget is met by the drain itself) and is safe; it merely serves as documentation. If the workload is both single-replica and disruption-sensitive, the design problem is the replica count, not the PDB.

## Probe semantics and interaction

- `startupProbe` for workloads with variable or long warmup (app server loading caches, JVM tuning, DB-schema verification). Without it, liveness may kill a slowly starting container repeatedly.
- `readinessProbe` before `livenessProbe` — a freshly-started Pod goes not-ready first, then not-live. If the readiness path fails perpetually but liveness succeeds, the Pod stays up but serves no traffic (intended behavior).
- `livenessProbe` tests "I am hard-broken and need a restart"; it should not test external dependencies (DB, downstream services). Coupling liveness to a DB causes cascading restarts when the DB blips.
- `terminationGracePeriodSeconds` long enough for in-flight request drain + `preStop` hook; default 30s is often too short for anything that holds long-lived connections.
- Probe intervals (`periodSeconds`) tuned: too aggressive causes thrash on transient issues; too lax causes slow recovery.

## Graceful shutdown

- `lifecycle.preStop` hook for workloads that hold stateful connections (websockets, long-polling, draining queues). Without it, SIGTERM is sent and the container has `terminationGracePeriodSeconds` to self-finalize.
- `preStop` commonly sleeps briefly to allow endpoint-controller propagation to remove the Pod from Service endpoints before traffic stops arriving.
- Application handles SIGTERM: stop accepting new work, finish in-flight work, flush buffers, exit. An application that ignores SIGTERM and requires SIGKILL is a reliability finding.
- `terminationGracePeriodSeconds` sized to `preStop duration + worst-case drain time + SIGTERM processing time`.
- Jobs set `activeDeadlineSeconds` so a wedged Pod doesn't run forever; `backoffLimit` bounds retry.

## Anti-affinity and topology spread

- Multi-replica workloads should spread across failure domains:
  - Prefer `topologySpreadConstraints` over `podAntiAffinity` — GA since K8s 1.19, more expressive (declarative `maxSkew`, explicit topology keys, `matchLabelKeys` for version-scoped spread in 1.27+).
  - Typical topology keys: `kubernetes.io/hostname` (node-level), `topology.kubernetes.io/zone` (zone-level).
  - `whenUnsatisfiable: ScheduleAnyway` (soft) vs `DoNotSchedule` (hard) — hard spread can block scheduling when capacity is tight. Review the choice; soft is the safer default for application workloads, hard is appropriate for hard-isolation requirements (e.g., quorum services that must split across zones).
- `podAntiAffinity` with `requiredDuringSchedulingIgnoredDuringExecution` is hard; `preferredDuringSchedulingIgnoredDuringExecution` is soft. Mismatch between intent and type is common.
- StatefulSet: `serviceName` set and matches a headless Service; volume claim templates are stable.

## Rollout strategies

`Deployment.spec.strategy`:

- `RollingUpdate` (default): `maxUnavailable` and `maxSurge` tuned to the workload. Zero-downtime workloads want `maxUnavailable: 0`, `maxSurge: 1` (or `25%`).
- `Recreate`: terminates all old Pods before creating new ones — only appropriate when concurrent old+new versions cannot coexist (schema migrations, singleton workloads).
- `minReadySeconds` for workloads whose readiness isn't immediate — prevents a burst of new Pods declared ready too early.
- `progressDeadlineSeconds` so a stuck rollout surfaces rather than hanging forever.
- `revisionHistoryLimit` set to a small-but-useful number (3–10); the default (10) is fine. `revisionHistoryLimit: 0` disables `kubectl rollout undo` entirely and removes the ReplicaSet history that tools like Argo CD use for rollback/diff — flag as P2 unless the workload is ephemeral (CI runner, batch job) or an alternative rollback mechanism is documented.

For `StatefulSet`: `podManagementPolicy` (`OrderedReady` default, `Parallel` for workloads that tolerate concurrent startup); `updateStrategy.rollingUpdate.partition` for staged rollouts.

For `DaemonSet`: `updateStrategy` — `RollingUpdate` or `OnDelete`. Node-impacting DaemonSets (CNI, CSI) usually want `OnDelete` to avoid cluster-wide disruption.

## Job and CronJob reliability

- `Job.spec.backoffLimit` explicit (default 6) — controls retry cap.
- `Job.spec.activeDeadlineSeconds` to bound total job wall-clock time.
- `Job.spec.ttlSecondsAfterFinished` so completed Jobs don't accumulate.
- `CronJob.spec.concurrencyPolicy` (`Allow`, `Forbid`, `Replace`) — the default `Allow` can cause overlapping runs to pile up.
- `CronJob.spec.startingDeadlineSeconds` so a missed scheduled run doesn't fire late when the controller catches up.
- `CronJob.spec.successfulJobsHistoryLimit` / `failedJobsHistoryLimit` bounded to avoid etcd bloat.
- Timezone: `CronJob.spec.timeZone` — alpha in K8s 1.24 (feature gate off by default), beta and enabled by default in 1.25, GA in 1.27. Set explicitly on clusters running ≥1.25 with default feature gates; on older clusters, document that the schedule is in kube-controller-manager local time (usually UTC).

## Questions to ask

- "What happens when a node drains during a cluster upgrade?" — surfaces PDB + spread gaps.
- "What is the user experience during a rollout?" — tests strategy + probes + graceful shutdown together.
- "Is this Pod restart-safe? Is it drain-safe?" — they are different questions.
