# Feature Specification: kubernetes.core.k8s Module Standardization

**Feature Branch**: `004-k8s-module-refactor`

**Created**: 2026-07-04

**Status**: Draft

**Input**: User description: "The goal of this pass is to refactor the deployment scripts for consistency: Specifically to standardize on the use of the kubernetes.core.k8s module where appropriate. This module is already being utilized in some roles."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consistent Role Re-Run (Priority: P1)

An operator re-runs cluster provisioning against an existing cluster — both core cluster setup and addon deployment — and all Kubernetes resource operations complete idempotently using the `kubernetes.core.k8s` module, with consistent change detection (reporting `changed` only when actual resource state differs).

**Why this priority**: Idempotent, consistent module usage is the core ask of this refactor. It directly affects operator confidence and pipeline reliability.

**Independent Test**: Run both `cluster-core.yml` and `cluster-addons.yml` against a running cluster twice in succession. Verify no `kubectl` command tasks report spurious changes on the second run, and no existing smoke tests regress.

**Acceptance Scenarios**:

1. **Given** a running cluster with all components deployed, **When** both the `cluster-core.yml` and `cluster-addons.yml` playbooks are re-run, **Then** all resource-management tasks report `ok` (not `changed`) and no raw `kubectl apply/create/delete` commands are invoked.
2. **Given** a role that previously used `kubectl apply -f -` with a templated manifest, **When** the role runs, **Then** the resource is applied via `kubernetes.core.k8s` with idempotent state management.
3. **Given** a namespace that already exists, **When** a role attempts to create it, **Then** the task uses `kubernetes.core.k8s` and reports no change rather than failing with `AlreadyExists`.

---

### User Story 2 - Consistent Wait and Query Patterns (Priority: P2)

An operator runs provisioning and all readiness waits use `kubernetes.core.k8s_info` polling loops instead of imperative `kubectl wait` and `kubectl rollout status` commands.

**Why this priority**: Improves cross-platform portability and produces structured output that downstream tasks can consume, without relying on parsing kubectl stdout.

**Independent Test**: Deploy a single addon role (e.g., cert-manager) and verify no `kubectl wait` or `kubectl rollout status` tasks are present; readiness is polled via `kubernetes.core.k8s_info`.

**Acceptance Scenarios**:

1. **Given** a deployment being provisioned, **When** the role waits for readiness, **Then** it uses `kubernetes.core.k8s_info` with a `retries`/`until` loop checking resource conditions rather than `kubectl wait --for=condition=available`.
2. **Given** a DaemonSet rollout, **When** the role waits for rollout completion, **Then** it polls pod status via `kubernetes.core.k8s_info` rather than `kubectl rollout status`.

---

### User Story 3 - Exempt Operations Remain Unchanged (Priority: P3)

An operator provisions a cluster and all non-resource operations (k3s bootstrap health probes, Helm chart deployments, k3s service management) continue to use their existing mechanisms without change.

**Why this priority**: Prevents over-reach — some operations have no `kubernetes.core.k8s` equivalent and must remain as shell/command tasks.

**Independent Test**: Bootstrap a cluster from scratch and confirm kube-vip readiness probes (`/readyz`), Helm-based deployments (Traefik), and k3s service management tasks all execute correctly.

**Acceptance Scenarios**:

1. **Given** the kube-vip bootstrap sequence, **When** the role checks Kubernetes API readiness via the `/readyz` raw endpoint, **Then** this check continues to use `ansible.builtin.command` with `kubectl --raw=/readyz` (no `kubernetes.core.k8s` replacement exists for raw health probes).
2. **Given** the Traefik role, **When** the Helm chart is installed or upgraded, **Then** the Helm operation remains as an `ansible.builtin.shell` or `ansible.builtin.command` task.

---

### Edge Cases

- What happens when a manifest previously applied via `kubectl apply -f URL` (remote URL) is converted — does `kubernetes.core.k8s` with `src:` support remote URLs or must the manifest be fetched first?
- How does the wait pattern handle DaemonSet readiness where `kubernetes.core.k8s_info` may return intermediate states before all pods are scheduled?
- What happens if the `kubernetes.core` collection is not installed on the Ansible control node?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All Kubernetes resource creation, update, deletion, and scaling in refactored roles MUST use `kubernetes.core.k8s` rather than `ansible.builtin.command: kubectl apply/create/delete/patch/scale`. Scale operations MUST be replaced by patching the `replicas` field in the resource spec via `kubernetes.core.k8s`.
- **FR-002**: All Kubernetes resource queries in refactored roles that drive Ansible task logic (conditionals, `when:`, `until:` loops, `register:` values used in subsequent tasks) MUST use `kubernetes.core.k8s_info` rather than `ansible.builtin.command: kubectl get`. Diagnostic or observability-only `kubectl get` calls whose output is not used for flow control (e.g., `k3s-common/tasks/collect-ha-observations.yml`) are exempt.
- **FR-003**: Namespace creation MUST be handled by `kubernetes.core.k8s` with `state: present`, replacing imperative `kubectl create namespace` calls.
- **FR-004**: Readiness waits that previously used `kubectl wait --for=condition=available` MUST be replaced with `kubernetes.core.k8s_info` polling loops using `retries` and `until` conditions.
- **FR-005**: DaemonSet rollout waits that previously used `kubectl rollout status` MUST be replaced with `kubernetes.core.k8s_info` polling loops checking pod count or `ready` conditions.
- **FR-006**: All refactored tasks MUST produce correct idempotent change detection — reporting `changed: true` only when the resource state was actually modified.
- **FR-007**: In the `kube-vip` role, all manifest apply tasks (DaemonSet, cloud controller, and ConfigMap) MUST be migrated to `kubernetes.core.k8s`. All health-probe and diagnostic tasks (`/readyz`, `api-resources` discovery, `journalctl`, `systemctl status`) MUST remain as `ansible.builtin.command` tasks — these have no `kubernetes.core.k8s` equivalent and validate API availability before any apply step runs.
- **FR-008**: Helm-based deployments (e.g., Traefik) MUST remain as shell/command tasks — Helm operations are out of scope for this module.
- **FR-009**: k3s service management and version checks (`k3s --version`, systemd) MUST remain unchanged.
- **FR-010**: The `kubernetes.core` Ansible collection MUST be declared as a dependency in `ansible/requirements.yml` if not already present.
- **FR-011**: All roles that are refactored MUST continue to pass the existing idempotence smoke test (`tests/ansible/smoke/idempotence-test.yml`).
- **FR-012**: Manifests currently applied from remote URLs via `kubectl apply -f https://...` MUST be fetched at runtime using `ansible.builtin.uri` (with `return_content: true`) and then applied via `kubernetes.core.k8s` with `definition:` set to the parsed YAML content. No local file copy or temp file is required.

### Key Entities *(include if feature involves data)*

- **Refactored Role**: An Ansible role whose Kubernetes resource tasks are migrated from direct `kubectl` invocations to `kubernetes.core.k8s` / `kubernetes.core.k8s_info` modules. Roles in scope: `cert-manager`, `multus`, `traefik`, `rancher`, and `kube-vip` (DaemonSet apply task only — see kube-vip boundary below). `rancher-monitoring` is also in scope at lower priority (namespace creation and readiness wait only; its Helm install task remains exempt per FR-008) and is included in the DoD only after the higher-priority roles are complete.
- **Exempt Operation**: A task that legitimately stays as a shell/command invocation because no `kubernetes.core.k8s` equivalent exists: raw API health probes, Helm operations, k3s binary/service management.
- **Idempotence Gate**: The condition that a role applied twice to the same cluster produces no changes on the second run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero direct `kubectl apply`, `kubectl create`, `kubectl delete`, `kubectl patch`, or `kubectl scale` command invocations remain in the task files of all refactored roles (`cert-manager`, `multus`, `traefik`, `kube-vip`, `rancher`) after the refactor is complete. For `rancher-monitoring`, the same zero-kubectl standard applies to its namespace and wait tasks, conditional on completion of higher-priority roles.
- **SC-002**: Zero `kubectl get` command invocations remain in refactored role task files where the result was used for resource-state decisions (i.e., replaced by `kubernetes.core.k8s_info`).
- **SC-003**: The idempotence smoke test completes with no `changed` tasks on the second playbook run for all refactored roles.
- **SC-004**: Full `cluster-core.yml` and `cluster-addons.yml` playbook runs complete successfully on a clean cluster deployment following the refactor.
- **SC-005**: All existing smoke tests (`ha-disruption-test.yml`, `scale-test.yml`, `multus-dhcp-test.yml`) pass without modification after the refactor.

## Clarifications

### Session 2026-07-04

- Q: For kube-vip, which tasks are in scope for migration vs exempt? → A: Migrate all manifest apply tasks (DaemonSet, cloud controller, ConfigMap); all health-probe and diagnostic tasks (`/readyz`, `api-resources`, `journalctl`, `systemctl`) remain as `ansible.builtin.command`.
- Q: For cert-manager's remote URL manifests, what fetch approach is required? → A: `ansible.builtin.uri` (return_content: true) to fetch YAML at runtime, then apply via `kubernetes.core.k8s` with `definition:` — no local file copy.
- Q: Are `kubectl scale` commands in scope for migration under FR-001 and SC-001? → A: Yes — migrate to `kubernetes.core.k8s` patching the `replicas` field; SC-001 now explicitly covers `kubectl scale`.
- Q: Is `rancher-monitoring` definitively out of scope or conditionally in scope? → A: In scope at lower priority — only namespace creation and readiness wait tasks are migrated; Helm install remains exempt. Included in DoD only after higher-priority roles are complete.
- Q: Are `kubectl get` calls in `k3s-common/collect-ha-observations.yml` in scope under FR-002? → A: Exempt — diagnostic observation output not used for flow control; no idempotence or consistency benefit from migrating.

## Assumptions

- The `kubernetes.core` Ansible collection is already installed or available via `ansible/requirements.yml` — it is already used by the `synology-csi` and `rancher` roles.
- All roles run with access to a valid kubeconfig (at `/etc/rancher/k3s/k3s.yaml` or via `KUBECONFIG`) — no change to kubeconfig handling is required.
- Helm-based deployments (Traefik) are explicitly out of scope; the `kubernetes.core.helm` module is a separate concern and not part of this refactor.
- The kube-vip role's bootstrap API health probes (`/readyz`, `api-resources`) and all diagnostic tasks (`journalctl`, `systemctl status`) are exempt. All manifest apply tasks (DaemonSet, cloud controller, ConfigMap) are migrated to `kubernetes.core.k8s`; the existing readiness checks guarantee API availability before any apply step runs.
- Remote manifest URLs (e.g., cert-manager CRDs and deployment YAML from GitHub) will require a fetch step before applying via `kubernetes.core.k8s`; this is an acceptable trade-off for consistency.
- `rancher-monitoring` is in scope at lower priority. Only its `kubectl create namespace` and `kubectl wait` tasks are migrated; the Helm install operation remains exempt per FR-008. It is included in the DoD only after `cert-manager`, `multus`, `kube-vip`, `traefik`, and `rancher` are complete.
- No changes to playbook entry points, inventory, or group/host variables are required.
