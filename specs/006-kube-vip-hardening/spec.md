# Feature Specification: Kube-VIP Hardening

**Feature Branch**: `006-kube-vip-hardening`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Enhance and harden the Kube-VIP configuration and deployment by adding egress controller support, HA service leader election, DHCP-based load balancer assignment, and validated RBAC permissions."

## Clarifications

### Session 2026-07-12

- Q: What is the supported kube-vip egress model for this repository? -> A: Enable kube-vip egress prerequisites by default and use documented Service configuration with `externalTrafficPolicy: Local` for Services by default, with explicit Service-level opt-out.
- Q: How should explicit opt-out be represented? -> A: Use documented Service-level kube-vip annotations such as `kube-vip.io/ignore=true` rather than repository-specific workload selector logic.
- Q: How should service election be configured? -> A: Use documented kube-vip runtime configuration via `svc_election` and validate live failover behavior without inventing undeclared quorum policy controls.
- Q: What DHCP behavior is in scope? -> A: Support documented DHCP request patterns (`loadBalancerIP: 0.0.0.0`, `kube-vip.io/loadbalancerIPs`, optional hostname annotation) and validate observed assignment behavior.
- Q: What RBAC strategy should be enforced? -> A: Use a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider, enforced on every deploy and upgrade.
- Q: What should be the default state for `kube_vip_egress_enabled` and `kube_vip_dhcp_enabled`? -> A: Both are enabled by default.
- Q: Should automated tests be generated for this feature? -> A: Yes, generate automated validation where feasible for egress prerequisites, service election runtime configuration, DHCP request behavior, and RBAC binding correctness.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Stable Cluster Egress Identity (Priority: P1)

As a cluster operator, I want kube-vip egress prerequisites and Service shaping to be configured consistently so that supported outbound identity handling is available for Services by default unless they explicitly opt out.

**Why this priority**: Correctly wiring the supported kube-vip egress model avoids undocumented behavior and gives operators a reproducible default path for supported outbound identity handling.

**Independent Test**: Can be fully tested by verifying daemonset egress prerequisites and confirming that Services are eligible for kube-vip egress by default unless explicitly marked with documented kube-vip ignore behavior.

**Acceptance Scenarios**:

1. **Given** kube-vip egress is enabled, **When** the kube-vip daemonset is rendered, **Then** it includes the documented runtime settings needed for kube-vip egress support.
2. **Given** a Service is not annotated with `kube-vip.io/ignore=true`, **When** it is configured with `externalTrafficPolicy: Local`, **Then** the Service is eligible for documented kube-vip egress handling by default.
3. **Given** a Service is annotated with `kube-vip.io/ignore=true`, **When** kube-vip evaluates Services, **Then** that Service is explicitly opted out of kube-vip processing.

---

### User Story 2 - Reliable HA Service Addressing (Priority: P1)

As a cluster operator, I want high-availability service address management with automatic leader election so that service exposure remains available during node or process failures.

**Why this priority**: Automatic leadership handoff is critical for availability in HA clusters and prevents manual intervention during failover events.

**Independent Test**: Can be fully tested by verifying that kube-vip service election is enabled in the daemonset and that representative LoadBalancer Services are shaped correctly for live failover validation.

**Acceptance Scenarios**:

1. **Given** an HA control plane with service election enabled, **When** the kube-vip daemonset is applied, **Then** it enables documented per-Service election support through `svc_election`.
2. **Given** a Service exposed through the cluster load balancer, **When** it is configured with `externalTrafficPolicy: Local`, **Then** it is eligible for live service-election and failover validation.

---

### User Story 3 - Automatic Load Balancer Address Allocation (Priority: P2)

As a cluster operator, I want load balancer addresses to be assigned dynamically through DHCP so that I can reduce static IP management overhead.

**Why this priority**: Dynamic address allocation reduces manual configuration burden and speeds up service provisioning in environments where DHCP is the standard.

**Independent Test**: Can be fully tested by creating new load-balanced Services that use documented DHCP request patterns and verifying the request surface is rendered correctly.

**Acceptance Scenarios**:

1. **Given** DHCP-based allocation is enabled, **When** a new load-balanced Service is created with `loadBalancerIP: 0.0.0.0`, **Then** the Service requests a DHCP-managed address using a documented kube-vip path.
2. **Given** a Service provides `kube-vip.io/loadbalancerHostname`, **When** kube-vip evaluates the Service, **Then** the hostname request surface is available for DHCP-backed assignment workflows.

---

### User Story 4 - Permission-Safe Operations (Priority: P2)

As a cluster operator, I want validated and complete access permissions for Kube-VIP operations so that upgrades and restarts do not fail due to missing privileges.

**Why this priority**: Historical permission gaps caused runtime failures, so permission coverage is necessary for reliability and maintainability.

**Independent Test**: Can be fully tested by deploying in both fresh and upgrade scenarios and confirming all required Kube-VIP operational actions complete without permission-denied errors.

**Acceptance Scenarios**:

1. **Given** the hardened permission set is applied, **When** Kube-VIP performs control, election, and service management actions, **Then** no permission-denied errors occur.
2. **Given** a cluster upgrade or restart event, **When** Kube-VIP components are reconciled, **Then** permission-related recovery failures do not occur.

### Edge Cases

- When kube-vip egress is enabled without service election, validation must fail because documented kube-vip egress requires service election support.
- When a Service is not explicitly opted out of kube-vip egress but is missing `externalTrafficPolicy: Local`, validation must fail because the Service is not shaped for documented kube-vip egress handling.
- When multiple Services request DHCP-backed addresses simultaneously under constrained network capacity, validation focuses on request correctness and observed allocator behavior rather than undeclared retry policy controls.
- How does the system behave when an existing cluster has legacy permissions that conflict with the hardened permission model?
- What happens when multiple services request new load balancer addresses simultaneously under constrained network capacity?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support documented kube-vip egress configuration so that eligible LoadBalancer Services use kube-vip egress handling by default unless explicitly opted out.
- **FR-002**: System MUST allow operators to enable or disable egress control at cluster configuration time.
- **FR-003**: System MUST allow Services to opt out of kube-vip processing using documented kube-vip annotations.
- **FR-004**: System MUST support service leader election in high-availability mode for service address ownership.
- **FR-005**: System MUST automatically transfer service address ownership to a new leader when the current leader becomes unavailable.
- **FR-006**: System MUST support DHCP-based address allocation for cluster load-balanced services.
- **FR-007**: System MUST support documented DHCP request surfaces including `loadBalancerIP: 0.0.0.0`, `kube-vip.io/loadbalancerIPs`, and optional hostname annotations.
- **FR-008**: System MUST define and apply a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider that covers all operational actions required for egress, service election, and load balancer management.
- **FR-009**: System MUST fail with clear actionable diagnostics when required permissions are missing or denied.
- **FR-010**: System MUST support both fresh deployments and upgrades without introducing regressions to existing Kube-VIP-managed services.
- **FR-011**: System MUST provide operator-visible status signals indicating egress control state, service leadership state, and service address allocation outcomes.
- **FR-012**: System MUST document required configuration inputs and behavioral expectations for egress control, service election, DHCP allocation, and permission validation.
- **FR-013**: System MUST validate the documented prerequisites for kube-vip egress and DHCP support before applying runtime manifests.
- **FR-016**: System MUST enforce and reconcile the RBAC baseline on every deployment and upgrade run to prevent permission drift.
- **FR-017**: System MUST default `kube_vip_egress_enabled` and `kube_vip_dhcp_enabled` to enabled unless operators explicitly override them.
- **FR-018**: System MUST include automated validation, where feasible, for egress prerequisites, service-election runtime configuration, DHCP request behavior, and RBAC binding correctness across deployment and upgrade paths.

### Key Entities *(include if feature involves data)*

- **Egress Service Profile**: Defines the daemonset settings and Service annotations required for documented kube-vip egress handling.
- **Service Leadership Record**: Represents current ownership of service address control in HA mode.
- **DHCP Service Request**: Represents a Service requesting DHCP-backed load balancer allocation through documented kube-vip surfaces.
- **Permission Capability Set**: Enumerates required allowed actions for Kube-VIP operations.
- **Operational Status Signal**: Observable state indicating whether egress, election, address allocation, and permission checks are healthy.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of validated, non-opted-out Services include the traffic policy and documented Service configuration required for kube-vip egress handling.
- **SC-002**: At least 95% of HA leadership failover events complete automatically within 30 seconds without operator intervention.
- **SC-003**: At least 95% of newly created load-balanced services receive a valid dynamic address within 60 seconds of service creation.
- **SC-004**: Permission-related operational errors for Kube-VIP management actions are reduced to zero in post-deployment smoke tests for both fresh installs and upgrades.
- **SC-005**: Network operations effort for firewall allow-list updates is reduced by at least 50% compared with the previous node-based process.
- **SC-006**: Operators can complete feature configuration and verification using documented steps in under 15 minutes for a standard HA test environment.
- **SC-007**: Automated validation coverage exists for egress prerequisites, service election runtime configuration, DHCP request behavior, and RBAC binding checks for at least one fresh-deploy and one upgrade-path scenario.

## Assumptions

- Clusters targeted by this feature run in environments where high availability and load-balanced service exposure are already required.
- Network teams can validate outbound identity behavior using Services that follow the default documented kube-vip egress model, with explicit opt-out where required.
- DHCP infrastructure for service address assignment is available, reachable, and managed outside this feature scope.
- Existing cluster operations include regular deployment or upgrade cycles where permission regressions must be prevented.
- Non-HA environments may not use service leader election and can continue operating with existing behavior unless HA mode is enabled.
- Validation of this feature will include both fresh deployment and upgrade-path testing before release.
