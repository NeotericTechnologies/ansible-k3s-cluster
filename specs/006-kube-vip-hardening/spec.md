# Feature Specification: Kube-VIP Egress and HA Hardening

**Feature Branch**: `007-create-feature-branch`

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "Use the attached file to generate a detailed specification for kube-vip configuration and deployment updates."

## Clarifications

### Session 2026-07-18

- Q: Should DHCP mode apply only to selected services or consistently to all kube-vip LoadBalancer services when enabled? → A: If DHCP is enabled, it applies consistently across all kube-vip LoadBalancer services.
- Q: Should kube-vip egress apply only to selected workloads or default to all with opt-out? → A: Default applies to all, with explicit opt-out support.
- Q: Should RBAC regression checks block deployment when they fail? → A: Yes, RBAC regression checks are hard-fail deployment gates.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Standardize Egress Through Kube-VIP (Priority: P1)

As a cluster operator, I want outbound traffic to use kube-vip-managed egress addresses by default, with explicit opt-out support, so firewall rules can be managed against stable, known source IPs rather than changing node IPs.

**Why this priority**: Stable and predictable egress identity is the highest-value operational need in this request and directly reduces firewall rule complexity and incident risk.

**Independent Test**: Can be fully tested by enabling kube-vip egress, verifying default behavior across multiple workloads, and confirming opt-out workloads use non-egress default routing.

**Acceptance Scenarios**:

1. **Given** egress control is enabled, **When** a workload sends outbound traffic without an opt-out marker, **Then** traffic exits through the configured kube-vip egress address.
2. **Given** egress control is enabled, **When** the owning node for egress handling becomes unavailable, **Then** egress responsibility fails over and outbound traffic resumes with expected source identity within the defined recovery window.
3. **Given** egress control is enabled and a workload has explicit opt-out configured, **When** that workload sends outbound traffic, **Then** traffic follows default cluster routing without kube-vip egress assignment.

---

### User Story 2 - Enable HA Service Election for LoadBalancer Management (Priority: P1)

As a platform operator, I want kube-vip service election enabled in HA mode so a healthy leader is automatically selected to manage service advertisements, reducing manual failover actions.

**Why this priority**: Leader election is a primary requested capability and directly impacts service availability during node disruption.

**Independent Test**: Can be fully tested by running an HA cluster with service election enabled, simulating leader disruption, and confirming automatic leadership transfer without manual intervention.

**Acceptance Scenarios**:

1. **Given** an HA deployment with multiple eligible kube-vip instances, **When** service election is enabled, **Then** exactly one leader is elected for service advertisement at a time.
2. **Given** a current service-election leader fails or is drained, **When** remaining instances are healthy, **Then** a new leader is elected automatically and service advertisement continues.
3. **Given** the cluster is operating in non-HA mode, **When** service election settings are applied, **Then** behavior remains stable and does not block service exposure.

---

### User Story 3 - Support Optional DHCP-Based LoadBalancer Addressing (Priority: P1)

As a platform operator, I want an optional DHCP mode for kube-vip load balancer address assignment so I can use dynamic allocation in environments where static pools are not preferred, with one consistent behavior across all kube-vip LoadBalancer services when DHCP is enabled.

**Why this priority**: DHCP for kube-vip load balancers is a stated primary goal for this iteration and must be delivered as a first-class capability.

**Independent Test**: Can be fully tested by enabling DHCP mode in a target environment, provisioning multiple LoadBalancer services across namespaces, and validating that all kube-vip-managed services receive dynamic assignment and remain reachable.

**Acceptance Scenarios**:

1. **Given** DHCP mode is enabled and DHCP services are reachable, **When** kube-vip-managed LoadBalancer services are created, **Then** each service follows DHCP assignment behavior consistently and service connectivity is established.
2. **Given** DHCP mode is disabled, **When** LoadBalancer services are created, **Then** address assignment follows the configured non-DHCP mode.
3. **Given** DHCP mode is enabled, **When** a lease expires or is renewed, **Then** service availability is preserved within the defined disruption tolerance.

---

### User Story 4 - Harden and Verify Kube-VIP RBAC Bindings (Priority: P1)

As a platform operator, I want kube-vip RBAC bindings reviewed, corrected, and continuously validated so permission regressions do not break egress, election, or service advertisement behavior.

**Why this priority**: Prior RBAC issues already caused failures, so preventing repeat authorization outages is a high-impact reliability requirement for this iteration.

**Independent Test**: Can be fully tested by applying RBAC definitions in a clean environment and a previously affected environment, then validating all required kube-vip control loops run without authorization-denied errors.

**Acceptance Scenarios**:

1. **Given** kube-vip roles and bindings are applied, **When** kube-vip performs required cluster operations, **Then** no authorization-denied failures occur for supported egress, election, and service advertisement workflows.
2. **Given** kube-vip version or mode changes are introduced, **When** RBAC validation checks run, **Then** missing permissions are detected and deployment is blocked before production rollout.
3. **Given** an environment with previously broken bindings, **When** updated RBAC is applied, **Then** affected kube-vip components recover to healthy operation without manual privilege escalation.

---

### Edge Cases

- Egress control is enabled but no eligible egress address is available at runtime.
- Service election is enabled in a topology with only one eligible instance.
- Node role changes or temporary partitions create brief split-brain election signals.
- DHCP mode is enabled but DHCP lease allocation is delayed or exhausted.
- Existing static LoadBalancer assignments must remain stable during migration to or from DHCP mode.
- RBAC definitions drift from kube-vip capability requirements after version updates.
- Mixed workload scope where only a subset of namespaces or services should use egress control.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a configurable kube-vip egress control mode that can be enabled or disabled per cluster environment.
- **FR-002**: System MUST apply kube-vip-managed egress behavior by default to workloads in an enabled environment and support explicit workload or namespace opt-out controls.
- **FR-003**: System MUST ensure selected workloads use stable, policy-defined egress source identity when egress mode is enabled.
- **FR-004**: System MUST provide documented failover behavior for egress handling when a responsible instance becomes unavailable.
- **FR-005**: System MUST support service election for kube-vip service management in HA deployments.
- **FR-006**: System MUST ensure only one active service-election leader handles service advertisement responsibilities at any given time.
- **FR-007**: System MUST automatically recover service-election leadership after leader loss without requiring manual operator intervention.
- **FR-008**: System MUST provide an optional DHCP-based LoadBalancer address allocation mode that is applied consistently across all kube-vip-managed LoadBalancer services when enabled for an environment.
- **FR-009**: System MUST preserve compatibility with non-DHCP LoadBalancer address allocation when DHCP mode is disabled, with a single consistent non-DHCP behavior across kube-vip-managed LoadBalancer services.
- **FR-010**: System MUST define and apply RBAC permissions required for kube-vip egress, service election, and service advertisement operations.
- **FR-011**: System MUST include explicit RBAC validation checks that detect missing or insufficient permissions before production rollout and during change verification.
- **FR-012**: System MUST maintain an RBAC regression guard (documented verification procedure and repeatable checks) for kube-vip feature updates and version changes.
- **FR-013**: System MUST document operational runbooks for enabling, disabling, and verifying egress mode, service election, DHCP mode, and RBAC health.
- **FR-014**: System MUST enforce RBAC regression checks as hard-fail deployment gates for production rollout.

### Key Entities *(include if feature involves data)*

- **Egress Policy Profile**: Declares which workloads are governed by kube-vip egress, expected source identity, and failover expectations.
- **Service Election State**: Represents current leadership ownership and transition conditions for kube-vip service advertisement responsibilities.
- **LoadBalancer Address Allocation Policy**: Defines whether address allocation uses static range behavior or DHCP behavior for a given environment.
- **Kube-VIP RBAC Capability Set**: Defines required permissions and bindings for kube-vip to perform elected responsibilities and networking operations.
- **Deployment Verification Record**: Captures post-deployment checks for egress routing, election continuity, DHCP assignment outcomes, and authorization health.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of workloads explicitly enrolled in egress control present expected source identity in outbound connectivity checks.
- **SC-002**: During planned or unplanned leader loss in HA testing, service-election recovery completes within 60 seconds in at least 95% of test runs.
- **SC-003**: In DHCP-enabled environments, at least 95% of newly created LoadBalancer services receive routable addresses within 2 minutes of creation during acceptance testing.
- **SC-004**: Post-change validation reports zero authorization-denied errors for supported kube-vip control loops across three consecutive test deployments.
- **SC-005**: Operators can complete the documented verification workflow for all enabled modes (egress, election, DHCP/non-DHCP) in under 15 minutes per environment.

## Assumptions

- Existing cluster environments already use the repository's kube-vip role as the authoritative deployment path.
- HA behavior is expected only in inventories with multiple eligible server/control-plane nodes.
- DHCP mode is enabled only in environments with reachable, properly configured DHCP infrastructure.
- Required firewall policy updates are managed outside this repository once stable egress identities are verified.
- Existing non-DHCP service exposure behavior remains the default unless DHCP mode is explicitly enabled.

## Evidence & Verification *(mandatory)*

- **Confirmed Facts**:
  - Repository already includes a dedicated kube-vip role and deployment references in core playbooks: `ansible/roles/kube-vip/README.md`, `ansible/roles/kube-vip/tasks/install.yml`, `ansible/playbooks/cluster-core.yml`, `ansible/group_vars/all.yml`.
  - Current role documentation and defaults indicate control-plane VIP plus service load balancing are already in scope: `ansible/roles/kube-vip/README.md`, `ansible/roles/kube-vip/defaults/main.yml`.
  - Prior RBAC stability is a known concern per user-provided iteration brief and prior fix history.
  - External feature references provided by the user:
    - https://kube-vip.io/docs/usage/egress/
    - https://kube-vip.io/docs/usage/kubernetes-services/
    - https://github.com/kube-vip/kube-vip
    - https://github.com/kube-vip/kube-vip-cloud-provider
- **Assumptions**:
  - Egress policy scope and enrollment will be configured through existing repository variable and role patterns; validation will occur during planning and implementation.
  - Recovery windows and acceptance thresholds are set to practical defaults for HA operations and may be tuned during planning after environment benchmarking.
- **Unsupported Claims Check**:
  - No implementation framework, API surface, or repository-internal behavior is asserted without observed repository evidence or explicit external citation.
  - Any environment-specific performance outcomes are treated as verification targets, not guaranteed facts.
- **Source Hierarchy**:
  - Primary: observed repository files and user-provided requirements.
  - Secondary: official kube-vip documentation and source repositories where repository evidence is insufficient.
