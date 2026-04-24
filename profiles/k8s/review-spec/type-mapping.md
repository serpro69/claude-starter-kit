# K8s spec verification — type mapping and verification patterns

## The declarative shift

In imperative code, implementation is behavior — functions execute, routes respond, state mutates. In Kubernetes, implementation is declaration — a YAML manifest describes desired state, and a controller reconciles reality to match. This changes what each finding type means:

| Finding type | Imperative code | Kubernetes declarative |
|---|---|---|
| `MISSING_IMPL` | Function/route/handler not written | Manifest for a design-specified resource does not exist |
| `SPEC_DEV` | Function behaves differently than spec | Field value in manifest disagrees with design |
| `EXTRA_IMPL` | Code exists that spec doesn't describe | Manifest for a resource the design doesn't mention |
| `DOC_INCON` | Two doc sections contradict each other | Two doc sections contradict each other (unchanged) |
| `OUTDATED_DOC` | Docs describe old behavior | Docs describe old resource shape or removed resource |

**Absence is meaningful.** If the design specifies a PodDisruptionBudget and no PDB manifest exists, that is `MISSING_IMPL` — not "maybe they'll add it later" and not `DOC_INCON`. In declarative systems, the absence of a resource means the cluster will not have it.

## Resource-level verification

For each resource the design names or implies, verify a corresponding manifest exists:

- **Explicit resources.** The design says "create a NetworkPolicy" or "add a PDB with minAvailable: 2" — a manifest must exist. Absent → `MISSING_IMPL`.
- **Implied resources.** The design says "restrict network access to the database" — a NetworkPolicy (or equivalent) must implement that constraint. Absent → `MISSING_IMPL` with moderate confidence (the design didn't name the resource type, so interpretation applies).
- **Undocumented resources.** A manifest exists for a resource the design does not mention at all → `EXTRA_IMPL`. Common legitimate cases: ServiceAccount (often implicit), default ConfigMaps, RBAC bindings that the design assumed without stating. Note these but assess severity conservatively — many K8s resources are infrastructure plumbing the design reasonably omits.

## Field-level verification

For each resource whose shape the design constrains, verify field values match:

| Design constraint | Manifest field to check | Finding type if mismatch |
|---|---|---|
| Replica count | `spec.replicas` | `SPEC_DEV` |
| Image tag/digest | `spec.template.spec.containers[].image` (or `spec.containers[]` for bare Pods) | `SPEC_DEV` |
| Resource requests/limits | `spec.template.spec.containers[].resources` | `SPEC_DEV` |
| Probe paths and ports | `spec.template.spec.containers[].readinessProbe`, `livenessProbe`, `startupProbe` | `SPEC_DEV` |
| RBAC verbs and resources | `rules[].verbs`, `rules[].resources` | `SPEC_DEV` |
| Security context | `spec.template.spec.securityContext`, `containers[].securityContext` | `SPEC_DEV` |
| Env vars / config keys | `spec.template.spec.containers[].env[]`, `envFrom[]`, ConfigMap `data` keys | `SPEC_DEV` |
| Port numbers and names | `spec.template.spec.containers[].ports[].containerPort`, Service `spec.ports[].port` | `SPEC_DEV` |
| Tolerations and affinity | `spec.template.spec.tolerations[]`, `spec.template.spec.affinity` | `SPEC_DEV` |
| PDB minAvailable/maxUnavailable | `spec.minAvailable`, `spec.maxUnavailable` | `SPEC_DEV` |

**Precision matters.** A design that says "resource limits should be set" is satisfied by any non-zero limits. A design that says "memory limit: 512Mi" is only satisfied by exactly that value. Match your confidence to the precision of the design's language.

## Relationship-chain verification

Kubernetes resources reference each other through labels, selectors, and names. When the design describes a traffic flow or ownership chain, verify the connecting fields are consistent:

- **Deployment → Service → Ingress chain.** The Deployment's `spec.template.metadata.labels` must match the Service's `spec.selector`; the Service's `metadata.name` and `spec.ports[].port` must match the Ingress's `spec.rules[].http.paths[].backend.service.name` and `backend.service.port.number` (or `port.name`). Note: the `backend.serviceName`/`backend.servicePort` form indicates the removed `extensions/v1beta1` API and is itself a finding.
- **RBAC chain.** A RoleBinding's `roleRef` must name an existing Role; its `subjects[]` must reference the intended ServiceAccount(s). A design that says "the app service account can read secrets in its namespace" maps to a specific Role + RoleBinding + ServiceAccount triple.
- **HPA → target.** The HPA's `scaleTargetRef` must reference the correct Deployment/StatefulSet; the metrics it uses must be available.
- **NetworkPolicy → pods.** The `podSelector` in the NetworkPolicy must match the labels of the pods the design intends to protect.
- **ConfigMap/Secret → consumer.** Volumes, `envFrom`, and `env[].valueFrom` must reference ConfigMaps/Secrets that exist and contain the expected keys.

A broken chain where the design describes working connectivity is `SPEC_DEV`. A chain the design doesn't describe is informational — note it but don't flag as a finding unless it contradicts a design statement.

## Severity calibration for K8s findings

- **P0 (Critical):** Missing security resource the design requires (NetworkPolicy, RBAC restriction, Pod Security Standard), missing core workload (Deployment/StatefulSet the design describes as the feature's primary resource).
- **P1 (High):** Missing reliability resource (PDB, HPA) the design specifies, RBAC scope broader than design's security posture allows, broken relationship chain that would cause runtime failure.
- **P2 (Medium):** Field-value deviation (replica count, resource limits, probe timing), missing non-critical resource (ConfigMap for optional config), label mismatch that doesn't break selectors.
- **P3 (Low):** Annotation differences, label naming convention deviation, cosmetic ordering of manifest sections.
