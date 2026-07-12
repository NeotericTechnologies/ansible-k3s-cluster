# Feature Specification: Kube-VIP Hardening

**Feature Branch**: `006-kube-vip-hardening`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Enhance and harden the Kube-VIP configuration and deployment by adding egress controller support, HA service leader election, DHCP-based load balancer assignment, and validated RBAC permissions."

## Clarifications

### Session 2026-07-12

- Q: How should the system behave when DHCP is unavailable during service address assignment? -> A: Keep service in pending allocation state and retry automatically until DHCP becomes available.
- Q: Should managed egress be opt-in or default-on? -> A: Managed egress applies cluster-wide by default; workloads can explicitly opt out.
- Q: How should invalid/conflicting opt-out configuration be handled? -> A: Ignore invalid opt-out, keep managed egress active, and emit clear warning diagnostics.
- Q: How should service election behave when quorum is lost? -> A: Hold current healthy leader assignments, block new leadership changes, and report degraded state until quorum is restored.
- Q: What RBAC strategy should be enforced? -> A: Use a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider, enforced on every deploy and upgrade.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Stable Cluster Egress Identity (Priority: P1)

As a cluster operator, I want outbound cluster traffic to use managed, predictable egress identities so that firewall and allow-list management is simpler and safer.

**Why this priority**: Centralizing outbound identity directly reduces operational risk and support effort caused by changing node-level source addresses.

**Independent Test**: Can be fully tested by enabling egress control and validating that outbound traffic from selected workloads consistently uses assigned egress addresses that network teams can allow-list.

**Acceptance Scenarios**:

1. **Given** a running cluster with egress control enabled, **When** a workload initiates outbound traffic, **Then** the traffic is observed using the configured cluster egress identity by default.
2. **Given** firewall policies based on the configured egress identity, **When** workloads access approved external services, **Then** connectivity succeeds without requiring per-node firewall changes.
3. **Given** a workload is explicitly configured to opt out of managed egress, **When** it sends outbound traffic, **Then** it bypasses managed egress and follows standard cluster networking behavior.

---

### User Story 2 - Reliable HA Service Addressing (Priority: P1)

As a cluster operator, I want high-availability service address management with automatic leader election so that service exposure remains available during node or process failures.

**Why this priority**: Automatic leadership handoff is critical for availability in HA clusters and prevents manual intervention during failover events.

**Independent Test**: Can be fully tested by creating a load-balanced service, forcing the current leader to become unavailable, and verifying leadership and traffic handling transition automatically.

**Acceptance Scenarios**:

1. **Given** an HA control plane with service election enabled, **When** the active leader becomes unavailable, **Then** a new leader is elected automatically within the expected failover window.
2. **Given** a service exposed through the cluster load balancer, **When** leadership changes, **Then** inbound service access remains available with only brief, bounded disruption.

---

### User Story 3 - Automatic Load Balancer Address Allocation (Priority: P2)

As a cluster operator, I want load balancer addresses to be assigned dynamically through DHCP so that I can reduce static IP management overhead.

**Why this priority**: Dynamic address allocation reduces manual configuration burden and speeds up service provisioning in environments where DHCP is the standard.

**Independent Test**: Can be fully tested by creating new load-balanced services and verifying that valid addresses are assigned automatically from the DHCP-managed network without manual reservation steps.

**Acceptance Scenarios**:

1. **Given** DHCP-based allocation is enabled, **When** a new load-balanced service is created, **Then** the service receives a valid network address automatically.
2. **Given** an allocated service address lease expires or changes, **When** the environment updates the lease, **Then** service address state is reconciled without manual correction.

---

### User Story 4 - Permission-Safe Operations (Priority: P2)

As a cluster operator, I want validated and complete access permissions for Kube-VIP operations so that upgrades and restarts do not fail due to missing privileges.

**Why this priority**: Historical permission gaps caused runtime failures, so permission coverage is necessary for reliability and maintainability.

**Independent Test**: Can be fully tested by deploying in both fresh and upgrade scenarios and confirming all required Kube-VIP operational actions complete without permission-denied errors.

**Acceptance Scenarios**:

1. **Given** the hardened permission set is applied, **When** Kube-VIP performs control, election, and service management actions, **Then** no permission-denied errors occur.
2. **Given** a cluster upgrade or restart event, **When** Kube-VIP components are reconciled, **Then** permission-related recovery failures do not occur.

### Edge Cases

- When DHCP allocation is unavailable at service creation time, the service remains pending allocation and retries automatically until DHCP is available.
- When leader election quorum is unavailable, the system holds current healthy leader assignments, blocks new leadership changes, and reports degraded state until quorum is restored.
- When a workload has conflicting or invalid opt-out configuration, managed egress remains active and the system emits clear warning diagnostics.
- How does the system behave when an existing cluster has legacy permissions that conflict with the hardened permission model?
- What happens when multiple services request new load balancer addresses simultaneously under constrained network capacity?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support managed egress control so that all cluster workloads use defined outbound traffic identities by default.
- **FR-002**: System MUST allow operators to enable or disable egress control at cluster configuration time.
- **FR-003**: System MUST allow workloads to explicitly opt out of managed egress and preserve standard outbound behavior for those opted-out workloads.
- **FR-004**: System MUST support service leader election in high-availability mode for service address ownership.
- **FR-005**: System MUST automatically transfer service address ownership to a new leader when the current leader becomes unavailable.
- **FR-006**: System MUST support DHCP-based address allocation for cluster load-balanced services.
- **FR-007**: System MUST reconcile DHCP-assigned address lifecycle changes without requiring manual operator correction for normal lease events.
- **FR-008**: System MUST define and apply a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider that covers all operational actions required for egress, service election, and load balancer management.
- **FR-009**: System MUST fail with clear actionable diagnostics when required permissions are missing or denied.
- **FR-010**: System MUST support both fresh deployments and upgrades without introducing regressions to existing Kube-VIP-managed services.
- **FR-011**: System MUST provide operator-visible status signals indicating egress control state, service leadership state, and service address allocation outcomes.
- **FR-012**: System MUST document required configuration inputs and behavioral expectations for egress control, service election, DHCP allocation, and permission validation.
- **FR-013**: System MUST keep a service in pending allocation state and retry address assignment automatically when DHCP is temporarily unavailable.
- **FR-014**: System MUST ignore invalid or conflicting managed-egress opt-out configuration, keep managed egress active for the affected workload, and emit clear warning diagnostics.
- **FR-015**: System MUST hold current healthy service leadership assignments, block new leadership changes, and emit degraded-state status signals when election quorum is unavailable.
- **FR-016**: System MUST enforce and reconcile the RBAC baseline on every deployment and upgrade run to prevent permission drift.

### Key Entities *(include if feature involves data)*

- **Egress Policy Scope**: Defines which workloads are subject to managed outbound identity handling.
- **Egress Identity**: The outbound source identity used for network allow-list and firewall policy management.
- **Service Leadership Record**: Represents current ownership of service address control in HA mode.
- **Load Balancer Address Lease**: Represents dynamically assigned service addresses and their lifecycle state.
- **Permission Capability Set**: Enumerates required allowed actions for Kube-VIP operations.
- **Operational Status Signal**: Observable state indicating whether egress, election, address allocation, and permission checks are healthy.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of workloads intentionally placed under egress control present the configured outbound identity during validation tests.
- **SC-002**: At least 95% of HA leadership failover events complete automatically within 30 seconds without operator intervention.
- **SC-003**: At least 95% of newly created load-balanced services receive a valid dynamic address within 60 seconds of service creation.
- **SC-004**: Permission-related operational errors for Kube-VIP management actions are reduced to zero in post-deployment smoke tests for both fresh installs and upgrades.
- **SC-005**: Network operations effort for firewall allow-list updates is reduced by at least 50% compared with the previous node-based process.
- **SC-006**: Operators can complete feature configuration and verification using documented steps in under 15 minutes for a standard HA test environment.

## Assumptions

- Clusters targeted by this feature run in environments where high availability and load-balanced service exposure are already required.
- Network teams can validate outbound identity behavior and maintain firewall rules using the cluster-level egress identity model.
- DHCP infrastructure for service address assignment is available, reachable, and managed outside this feature scope.
- Existing cluster operations include regular deployment or upgrade cycles where permission regressions must be prevented.
- Non-HA environments may not use service leader election and can continue operating with existing behavior unless HA mode is enabled.
- Validation of this feature will include both fresh deployment and upgrade-path testing before release.
