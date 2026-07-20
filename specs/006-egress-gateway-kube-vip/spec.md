# Feature Specification: Egress Gateway and Kube-VIP Enhancements

**Feature Branch**: `006-egress-gateway-kube-vip`

**Created**: 2026-07-19

**Status**: Draft

**Input**: docs/ai-prompts/spec-egress-gateway-and-kube-vip-updates.md

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Load-Balanced Egress Gateway (Priority: P1)

Cluster operator configures a dedicated egress gateway so all outbound traffic from the cluster exits through a single, predictable IP address with an associated hostname, enabling stable firewall rules.

**Why this priority**: Core stated goal of the feature. Predictable egress IP is a prerequisite for reliable perimeter firewall management. Without it, firewall rules must track per-node IPs.

**Independent Test**: Deploy the egress gateway configuration, then from a pod inside the cluster make an outbound HTTP request to an external echo service. Verify the observed source IP matches the configured egress IP, not a node IP.

**Acceptance Scenarios**:

1. **Given** a k3s cluster with the kube-vip role applied and a valid IP range configured, **When** the operator enables egress gateway via Ansible variables and runs the playbook, **Then** a load-balanced egress gateway is provisioned with a dedicated IP from the configured pool and an associated hostname.
2. **Given** the egress gateway is provisioned and Cilium Egress Gateway policy is applied, **When** any pod in the cluster makes outbound connections, **Then** Cilium steers pod traffic through the Kube-VIP LoadBalancer VIP so outbound traffic exits from the egress IP, not individual node IPs.
3. **Given** the egress gateway is provisioned, **When** a node hosting the gateway fails in HA mode, **Then** the gateway IP fails over to another node and outbound traffic resumes within the Kube-VIP lease renewal window.
4. **Given** egress gateway is disabled (`kube_vip_egress_enabled: false`), **When** the playbook runs, **Then** no egress gateway resources are created or modified.

---

### User Story 2 - Kube-VIP Service Election for HA (Priority: P2)

In HA clusters, the operator enables service leader election so Kube-VIP LoadBalancer services automatically elect a leader node, preventing split-brain IP assignment.

**Why this priority**: Prerequisite for reliable HA LoadBalancer behavior. Without election, multiple nodes may try to own the same service VIP simultaneously.

**Independent Test**: Configure a 3-node HA cluster with service election enabled. Create a LoadBalancer service and verify only one node owns the VIP. Cordon and drain that node; verify VIP migrates to another node.

**Acceptance Scenarios**:

1. **Given** an HA cluster (≥2 control-plane nodes) with service election enabled, **When** a LoadBalancer service is created, **Then** exactly one node is elected leader for that service VIP.
2. **Given** service election enabled, **When** the leader node becomes unavailable, **Then** a new leader is elected within the configured lease duration and the service VIP remains reachable.
3. **Given** a single-node cluster, **When** service election is enabled, **Then** the playbook applies the configuration without error and the single node acts as leader.

---

### User Story 3 - DHCP for Kube-VIP Load Balancers (Priority: P3)

The operator enables DHCP-based IP assignment for Kube-VIP LoadBalancer services, allowing the network infrastructure to assign IPs dynamically rather than from a static pool.

**Why this priority**: Optional enhancement for environments where static IP range management is impractical. Does not block P1/P2 delivery.

**Independent Test**: Enable DHCP mode, create a LoadBalancer service without an explicit `loadBalancerIP`, and verify the service receives an IP via DHCP from the network infrastructure.

**Acceptance Scenarios**:

1. **Given** DHCP mode enabled (`kube_vip_lb_dhcp_enabled: true`), **When** a LoadBalancer service is created without a static IP, **Then** Kube-VIP requests an IP via DHCP and assigns it to the service.
2. **Given** DHCP mode disabled (default), **When** the playbook runs, **Then** static IP range configuration from `kube_vip_lb_ip_range` is used and DHCP resources are not deployed.
3. **Given** both DHCP and static range are configured, **When** the playbook runs, **Then** the playbook fails with a clear error indicating only one mode may be active.

---

### User Story 4 - Consolidated RBAC for Kube-VIP (Priority: P2)

The operator re-runs the kube-vip role after an upgrade and the RBAC resources reflect all required permissions without manual patching, preventing future permission failures like those addressed in the prior `Generated fixes for Kube-VIP` commit.

**Why this priority**: Directly addresses a known past breakage. Reduces operational risk on every subsequent upgrade cycle.

**Independent Test**: Apply the role to a fresh cluster and to an existing cluster that has the old RBAC. Verify no RBAC-related errors appear in kube-vip pod logs and that all required API operations succeed.

**Acceptance Scenarios**:

1. **Given** a cluster with outdated Kube-VIP RBAC, **When** the kube-vip role runs, **Then** ClusterRole and ClusterRoleBinding resources are reconciled to include all required verbs and resources.
2. **Given** updated RBAC applied, **When** kube-vip and kube-vip-cloud-controller pods start, **Then** no RBAC-denied errors appear in pod logs.
3. **Given** the role runs multiple times (idempotent), **When** RBAC already matches desired state, **Then** no changes are made and playbook reports `ok` for RBAC tasks.

---

### Edge Cases

- What happens when the configured egress IP is already in use on the network?
- How does the system behave if `kube_vip_lb_dhcp_enabled` is true but no DHCP server is reachable?
- What occurs when service election is enabled on a cluster with fewer than `kube_vip_ha_min_replicas` nodes?
- How are RBAC changes applied when the existing ClusterRole has additional custom rules not managed by Ansible?
- What happens if Cilium is not installed or is not the active CNI when egress gateway is enabled?
- How does the `CiliumEgressGatewayPolicy` behave during a Kube-VIP VIP failover event — is there a traffic blackout window?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Playbook MUST support enabling a load-balanced egress gateway via an Ansible variable (`kube_vip_egress_enabled`), defaulting to `false`.
- **FR-002**: When egress gateway is enabled, a dedicated VIP MUST be allocated from a dedicated variable `kube_vip_egress_ip` (independent of `kube_vip_lb_ip_range`) and associated with a configurable hostname (`kube_vip_egress_hostname`); this VIP is managed by Kube-VIP as a LoadBalancer service endpoint.
- **FR-003**: Egress gateway VIP MUST fail over to another node within the Kube-VIP lease renewal window when the active node fails in HA mode.
- **FR-003a**: When egress gateway is enabled, a Cilium `CiliumEgressGatewayPolicy` resource MUST be applied to steer pod egress traffic through the Kube-VIP egress VIP; the target gateway node selector MUST be configurable via Ansible variables.
- **FR-003b**: Cilium MUST be the active CNI for the cluster; the playbook MUST fail with a descriptive error if Cilium is not detected.
- **FR-003c**: This feature MUST include an Ansible role (`cilium`) to install and configure Cilium as the CNI, replacing Flannel. k3s MUST be configured with `--flannel-backend=none` and `--disable-network-policy` when Cilium is enabled. Cilium version MUST be pinned via `cilium_version` variable.
- **FR-004**: Playbook MUST support enabling Kube-VIP service leader election via an Ansible variable (`kube_vip_svc_election_enabled`), defaulting to `false`.
- **FR-005**: When service election is enabled, exactly one node MUST hold the service VIP lease at any time.
- **FR-006**: Playbook MUST support enabling DHCP-based IP assignment for LoadBalancer services via an Ansible variable (`kube_vip_lb_dhcp_enabled`), defaulting to `false`.
- **FR-007**: `kube_vip_lb_dhcp_enabled: true` and a non-empty `kube_vip_lb_ip_range` MUST be mutually exclusive; the playbook MUST fail with a descriptive error if both are set.
- **FR-008**: The kube-vip ClusterRole and ClusterRoleBinding MUST be declared in full in the Ansible template and applied idempotently with `state: present`, overwriting any existing state; no detection or migration of custom rules is required.
- **FR-009**: The kube-vip-cloud-controller ClusterRole and ClusterRoleBinding MUST be separately declared and applied idempotently with `state: present`, overwriting any existing state, with all required permissions.
- **FR-010**: All new variables MUST have documented defaults in `ansible/roles/kube-vip/defaults/main.yml` and be documented in the role's `README.md`.
- **FR-011**: All tasks MUST be idempotent; re-running the playbook on an unchanged cluster MUST report no changes.
- **FR-012**: `docs/ansible-k3s-baseline.md` MUST be updated to remove the Flannel-only / no-Cilium non-goal statement and document Cilium as the supported CNI with egress gateway capability.
- **FR-013**: A smoke test MUST be added at `tests/ansible/smoke/egress-gateway-test.yml` that verifies outbound pod traffic exits through the configured egress VIP (observable via source IP check).

### Key Entities

- **Egress Gateway VIP**: A virtual IP configured via `kube_vip_egress_ip` (independent of the LoadBalancer pool), with an associated hostname (`kube_vip_egress_hostname`), used as the cluster's stable outbound traffic source.
- **Service Leader Election Lease**: A Kubernetes Lease object (`coordination.k8s.io`) used by Kube-VIP to elect a single node as the active owner of a service VIP.
- **Kube-VIP ClusterRole**: The RBAC ClusterRole granting kube-vip DaemonSet the API permissions required to manage VIPs and leases.
- **Kube-VIP Cloud Controller ClusterRole**: The RBAC ClusterRole granting the kube-vip-cloud-provider deployment permissions to reconcile LoadBalancer service status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Outbound traffic from any pod routes through the designated egress VIP — verifiable by external source-IP check — within 5 minutes of role application.
- **SC-002**: Egress VIP recovers on another node within the configured lease duration (default: 15 seconds) when the active node fails.
- **SC-003**: LoadBalancer service VIP ownership stabilizes to exactly one node within 10 seconds of service creation when election is enabled.
- **SC-004**: Zero RBAC-denied errors in kube-vip and kube-vip-cloud-controller pod logs after role application on both fresh and upgraded clusters.
- **SC-005**: Playbook runs are idempotent — zero changed tasks on second application against an unchanged cluster.
- **SC-006**: All new configuration options are controllable via inventory variables without modifying role files.
- **SC-007**: `docs/ansible-k3s-baseline.md` updated to reflect Cilium CNI and egress gateway capability before merge.
- **SC-008**: `tests/ansible/smoke/egress-gateway-test.yml` passes, confirming pod egress exits through the configured VIP.

## Assumptions

- Target clusters run k3s (not kubeadm); kube-vip DaemonSet runs on control-plane nodes only, consistent with existing role configuration.
- Egress gateway is a combined solution: Kube-VIP provides a stable, HA LoadBalancer VIP for the egress IP; Cilium Egress Gateway (`CiliumEgressGatewayPolicy`) steers all pod egress traffic through that VIP. Both components are required.
- This feature introduces Cilium as the CNI, replacing Flannel. Cilium installation is in scope and automated via a new `cilium` Ansible role.
- Kube-VIP version `v1.1.2` (currently pinned in `group_vars/all.yml`) supports service election and DHCP modes; if a version upgrade is required for these features, that is out of scope for this feature and must be tracked separately.
- DHCP mode requires an external DHCP server on the cluster network — provisioning the DHCP server is out of scope.
- Multus DHCP (already implemented) is independent of Kube-VIP DHCP; no interaction between the two is assumed.
- Consolidating RBAC means the templates become the single source of truth; any manually applied custom rules not in the templates will be overwritten on next role run. No migration detection step is required — this is by design.
- Egress gateway hostname DNS registration is out of scope; the operator manages DNS separately.
- Mobile and UI concerns are not applicable to this infrastructure feature.

## Evidence & Verification *(mandatory)*

- **Confirmed Facts**:
  - Kube-VIP role exists at `ansible/roles/kube-vip/` with DaemonSet, cloud controller, and ConfigMap templates (observed directly).
  - Current RBAC covers: `services`, `services/status`, `nodes`, `endpoints`, `endpointslices`, `leases` — observed in `kube-vip-daemonset.yaml.j2` and `kube-vip-cloud-controller.yaml.j2`.
  - Prior RBAC fix documented in feature description as `Generated fixes for Kube-VIP` commit — confirms RBAC has been a past failure point.
  - Current variables: `kube_vip_lb_enable`, `kube_vip_lb_ip_range`, `kube_vip_interface`, `kube_vip_version` in `defaults/main.yml` and `group_vars/all.yml` (observed directly).
  - No egress gateway, service election, or DHCP variables exist in the current role (observed directly — no such variables in `defaults/main.yml`).
  - Cilium is NOT currently present in this repository; `docs/ansible-k3s-baseline.md` line 170 explicitly states "No Calico/Cilium integration" (observed directly). Cilium installation is in scope for this feature — a new `cilium` role will be created to replace Flannel.
- **Assumptions**:
  - Kube-VIP v1.1.2 supports election and DHCP — must be validated against kube-vip release notes before implementation.
  - Egress gateway can be implemented as a reserved LoadBalancer VIP — must be validated against kube-vip documentation during planning.
- **Unsupported Claims Check**: No unsupported claims remain. All capability statements are marked as assumptions pending validation.
- **Source Hierarchy**: All confirmed facts derived from direct observation of repository files. External kube-vip capabilities cited as assumptions pending documentation review.

## Clarifications

### Session 2026-07-19

- Q: What should the egress gateway cover — all pod egress forced through egress VIP, or only traffic routed via LoadBalancer services? → A: All pod egress (Option A). Kube-VIP provides the stable HA VIP; Cilium Egress Gateway steers all pod traffic through it — combined solution.
- Q: How is the egress IP designated — reserved from `kube_vip_lb_ip_range` or via a dedicated variable? → A: Dedicated variable `kube_vip_egress_ip`, independent of the LB pool.
- Q: Is Cilium installation in scope for this feature or assumed pre-installed? → A: In scope (Option B). New `cilium` Ansible role installs Cilium as CNI, replacing Flannel.
- Q: RBAC overwrite behavior on upgrade — clean overwrite, warn, or fail-safe? → A: Clean overwrite (Option A). Templates are single source of truth; `state: present` reconciles without custom rule detection.
- Q: Traceability artifact for constitution §V compliance — tasks.md only, docs+smoke test, or full changelog? → A: Docs update + smoke test (Option B). Update `docs/ansible-k3s-baseline.md` and add `tests/ansible/smoke/egress-gateway-test.yml`.
