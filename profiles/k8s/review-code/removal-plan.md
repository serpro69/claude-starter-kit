# Kubernetes — Removal Plan

Template for reviewing Kubernetes resource removal. Applied whenever the `k8s` profile is active; use when the diff deletes manifests or when a retirement is in scope.

Kubernetes removals are high-stakes because resources are often load-bearing at runtime (workloads, Services, CRDs holding live instances) and deleting the manifest deletes the live object on `kubectl apply --prune` or a GitOps reconcile. Stage the work: audit first, decide per-resource, remove the safe ones, defer the dangerous ones with a plan.

## Safe to remove now

Resources where removal is a pure cleanup with no runtime consequence:

- **Orphan `ConfigMap` or `Secret`** — verify no references: `kubectl get all` is notoriously incomplete (it covers only Pod/Service/Deployment/ReplicaSet/StatefulSet/DaemonSet/Job/CronJob/ReplicationController — it MISSES ConfigMap/Secret/PVC/Ingress/NetworkPolicy/ServiceAccount/RBAC/CRDs). Use a targeted sweep instead: `kubectl get pod,deploy,sts,ds,job,cronjob,svc,ing,cm,secret,pvc,netpol,sa,role,rolebinding -A -o yaml | grep <name>`, and cross-check with `kubectl describe` for volume/env mounts.
- **Unreferenced `Service`** — no `Endpoints`, no `Ingress` target, no internal DNS consumers. Check logs and service-mesh routing before assuming unreferenced.
- **Unreferenced `ServiceAccount`** — no Pod uses it via `spec.serviceAccountName`, no `RoleBinding` / `ClusterRoleBinding` cites it.
- **Unused `Role` / `ClusterRole`** — no `RoleBinding` / `ClusterRoleBinding` references them.
- **Stale `HorizontalPodAutoscaler`** targeting a removed Deployment.
- **Completed `Job`** resources whose output has been consumed and retention is no longer needed (set `ttlSecondsAfterFinished` going forward).
- **Old `ReplicaSet` revisions** beyond `revisionHistoryLimit` — controller-managed; rarely need manual removal, but they are safe to prune.
- **Unused `NetworkPolicy`** that selects a workload that no longer exists.

For all "safe to remove now" items, removing the manifest and letting the cluster-reconcile controller delete the object is fine. Verify with `kubectl get <kind> <name>` post-removal.

## Defer with plan

Resources whose removal has runtime consequences requiring explicit coordination:

- **`CustomResourceDefinition` with existing instances (CRs).**
  - Deleting a CRD cascades to all its CRs — data loss. Verify instance count: `kubectl get <cr-kind> --all-namespaces`.
  - Remove CRs first (or migrate them), then remove the CRD.
  - If the CRs are load-bearing (cert-manager `Certificate`, ArgoCD `Application`), plan a migration path (new CRD version, alternative controller) before removing.
- **Resources owned by an Operator.**
  - Don't delete via manifest removal — the operator may recreate them on the next reconcile, or deletion may cascade to resources the operator was managing.
  - Remove at the operator's abstraction level (delete the owning CR), then optionally remove the CRD.
- **`Namespace` with persistent workloads.**
  - Deleting a Namespace cascades to everything in it, including `PersistentVolumeClaim` resources.
  - `PersistentVolume` behavior depends on the PV's `reclaimPolicy`: `Retain` keeps the underlying storage; `Delete` destroys it.
  - Migrate workloads out, snapshot PVs if retention is needed, THEN delete the namespace.
- **`PersistentVolume` / `PersistentVolumeClaim`.**
  - Deleting a PVC may or may not delete the PV (`reclaimPolicy` again). Backup the underlying storage first.
  - StatefulSet PVCs are NOT deleted by default when the StatefulSet is deleted — they persist intentionally. Review the policy before assuming cleanup.
- **`StatefulSet`.**
  - Deleting a StatefulSet does not delete its Pods' PVCs; data survives. For intentional full deletion, delete PVCs explicitly.
  - Stable network identities (pod-0, pod-1) mean dependencies on Pod names break on recreate.
- **`Deployment` / `Service` for a publicly-reachable workload.**
  - Downstream consumers may cache DNS or keep long-lived connections; removal can cause thundering-herd reconnects or timeout storms.
  - Plan a graceful transition: drain via NP or scaled-down replicas, announce deprecation, remove after a stabilization window.
- **`RoleBinding` / `ClusterRoleBinding` serving an automated principal.**
  - Removing a binding the CI/CD system relies on breaks deployments silently.
  - Verify by checking which `ServiceAccount`s the binding enables, and what workloads use those SAs.
- **`NetworkPolicy` changes that tighten defaults.**
  - Tightening NPs can block traffic that was previously allowed. Review with staged rollout: introduce on one namespace first, monitor, widen.

For deferred items, the manifest should either remain until the migration is complete, OR be removed with a `metadata.finalizers:` guard if the controller supports one.

## Checklist before removal

For every resource being removed:

- [ ] **Finalizer audit.** `kubectl get <kind> <name> -o jsonpath='{.metadata.finalizers}'` — nonzero means removal will hang until the finalizer is processed (or force-removed, which risks leaks).
- [ ] **Consumer check.** Who calls this? For Services: `kubectl get ep <svc>` + downstream DNS consumers. For CRDs: `kubectl get <kind> -A`. For Secrets/ConfigMaps: `grep` manifests + `kubectl describe pods` for volume/env mounts. Do NOT rely on `kubectl get all` — it misses ConfigMaps, Secrets, PVCs, Ingresses, NetworkPolicies, RBAC, and CRDs.
- [ ] **Owner-reference check.** `kubectl get <kind> <name> -o yaml | grep ownerReferences` — if owned by another resource, delete the owner, not the owned resource.
- [ ] **Backup.** For stateful resources (Secrets, PVCs, Ingress TLS), snapshot to a secure location before removal.
- [ ] **Rollback plan.** How do you restore? `kubectl apply` of the removed manifest from git? A prior Helm release? A restore from backup? Write it down before removing.
- [ ] **Communication.** Notify dependent teams (or internal consumers) before removing public endpoints or shared CRDs. A removal PR should link to the deprecation notice.
- [ ] **Staged execution.** Prod last; observe monitoring; a canary window (hours, not minutes, for anything load-bearing) before widening.
- [ ] **GitOps state verification.** For GitOps-managed clusters (ArgoCD, Flux), confirm the reconciler will pick up the removal and not revert it. Some policies require a manual sync.

## Multi-step sequencing

For a typical "retire an application" removal:

1. Scale to zero (`replicas: 0`) via a PR — workload stops serving, resources remain. Observe for days.
2. Remove network exposure (`Ingress`, `Service`) — external callers start failing loudly. Observe.
3. Remove workload manifests (`Deployment`, `HPA`, `PDB`) — cluster frees compute.
4. Remove data (PVCs), secrets, configmaps — the actual destructive step. Confirm backups.
5. Remove RBAC (`ServiceAccount`, `Role`, `RoleBinding`) — no more identity.
6. Remove the namespace if it was app-dedicated.

Each step is a separate PR; each is reversible by re-applying (except step 4).

## Questions to ask

- "What happens in the cluster if this manifest disappears?" — forces thinking beyond the file.
- "Can I roll back in 5 minutes if this goes wrong?" — drives backup + rollback-plan discipline.
- "Who depends on this resource that doesn't know I'm removing it?" — surfaces implicit consumers.
