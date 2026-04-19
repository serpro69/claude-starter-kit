# Kubernetes — Quality Checklist

Idiomatic manifest quality signals. Applied whenever the `k8s` profile is active. Findings are usually P2/P3; some (missing requests/limits, `:latest` tags) escalate.

## Contents

- Labels and annotations
- Image tags and digests
- Resource requests and limits
- Probes
- Ports, naming, and discoverability
- Declarative patterns

## Labels and annotations

The recommended label set (SIG Apps, `kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/`) applied consistently on every top-level resource:

- `app.kubernetes.io/name` — the name of the application.
- `app.kubernetes.io/instance` — unique name identifying this instance.
- `app.kubernetes.io/version` — the application's version (semver or git SHA).
- `app.kubernetes.io/component` — the component role within the architecture (`api`, `worker`, `cache`).
- `app.kubernetes.io/part-of` — the higher-level product this is part of.
- `app.kubernetes.io/managed-by` — the tool managing the resource (`Helm`, `kustomize`, `argocd`).

Propagate the relevant labels to the Pod template (`spec.template.metadata.labels`) so logs, metrics, and events are queryable.

**Annotations** vs labels: annotations carry non-identifying metadata (git commit, deploy timestamp, owner, documentation URLs). Data used for selection goes into labels; narrative data goes into annotations. A long free-text note in a label is a finding.

## Image tags and digests

- `:latest`, `:stable`, `:main`, and other mutable tags are P1 findings — the image contents change without the manifest changing, which makes rollouts unreproducible.
- Immutable tags (semver-pinned, build-id-pinned) are acceptable; digests (`repo/img@sha256:...`) are preferred for production.
- `imagePullPolicy` set explicitly: `IfNotPresent` for pinned tags/digests, `Always` only when mutability is an intentional property (rare).
- Registry paths include the registry host (`ghcr.io/org/img:1.2.3`, not `org/img:1.2.3`) so the pull source is unambiguous and does not depend on Docker Hub implicit defaults.

## Resource requests and limits

- Every container sets `resources.requests` (`cpu` and `memory`) — without requests, the scheduler uses BestEffort placement and the workload is evicted first under pressure.
- Every container sets `resources.limits.memory` — without a memory limit, a leaking process can OOM the node. (Memory limits without requests is also a finding — they differ.)
- CPU limits are contentious: they prevent noisy-neighbor effects but can cause throttling that hurts latency. Absence of `cpu` limit is acceptable when the workload's noisy-neighbor risk is analyzed; blind absence is a finding.
- Requests/limits ratio: when both are set, `limits.memory` should equal `requests.memory` for predictable QoS class `Guaranteed`; CPU can diverge.
- Ephemeral storage: `resources.requests.ephemeral-storage` and `limits.ephemeral-storage` for workloads writing to emptyDir or container filesystems — prevents node disk exhaustion.

## Probes

- `readinessProbe` and `livenessProbe` are **distinct concerns** — do not use the same probe for both:
  - `readinessProbe` gates traffic: "should I receive requests right now?". Failing a readiness probe removes the Pod from Service endpoints but does not restart it.
  - `livenessProbe` restarts the container: "am I wedged and unrecoverable?". Failing it kills the container.
  - Using the same HTTP path for both means a brief readiness blip triggers a restart, which is usually wrong.
- `startupProbe` for slow-starting applications — lets liveness/readiness use short intervals without fighting long warm-ups.
- Probe endpoints return cheaply (no DB round-trip on liveness; a cached readiness signal is fine).
- `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold`, `successThreshold` tuned to the workload — defaults are rarely optimal.
- HTTP probes specify the path and port explicitly; TCP probes are a fallback when HTTP is unavailable; `exec` probes are expensive and should be avoided.

## Ports, naming, and discoverability

- Container `ports[]` entries have `name` set — `Service.spec.ports[].targetPort` can then refer to port names, which survive port-number changes.
- Port names follow the IANA service-name rules (max 15 characters, lowercase, alphanumeric + `-`, must start/end with alphanumeric).
- `Service.spec.type` explicit (`ClusterIP`, `NodePort`, `LoadBalancer`) — defaulting to `ClusterIP` is fine but naming it makes intent clear.
- `Service.spec.ports[].appProtocol` set when the protocol matters (`http`, `grpc`, `tcp`) — helps ingress controllers and service meshes.

## Declarative patterns

- Manifests describe desired state, not actions. A manifest that includes shell commands to mutate cluster state via `lifecycle.postStart` hooks doing kubectl-like work is a finding.
- Prefer API-native primitives over creative workarounds: `PodDisruptionBudget` instead of custom "don't evict me" annotations; `NetworkPolicy` instead of per-Pod iptables rules; built-in probes instead of a liveness sidecar.
- Annotations on `Ingress` for controller-specific features (rewrite rules, timeouts, TLS settings) — keep them consistent within a project, not a mix of controllers' quirks on different ingresses.
- `Namespace` resources for every environment; avoid `default` namespace for workloads.
- `Kind: List` wrappers (multi-resource files) are acceptable but consider one resource per file for reviewability; if multi-resource, separate with `---`.

## Questions to ask

- "Could I roll this back by re-applying an older manifest?" — tests that nothing depends on mutable external state.
- "If I saw this manifest in production, could I tell which application, which version, which environment?" — tests labels.
- "What happens under memory pressure? Under CPU contention? Under a failed probe?" — tests resource/probe decisions.
