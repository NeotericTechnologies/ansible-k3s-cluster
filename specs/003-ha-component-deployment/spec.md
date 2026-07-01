# Feature Specification: HA Component Deployment

**Feature Branch**: `[003-create-feature-branch]`

**Created**: 2026-07-01

**Status**: Draft

**Input**: User description: "Ensure all core and addon components are deployed in a high availability configuration when the cluster has 3 or more server nodes, including replica expectations such as multi-replica controllers."

## Clarifications

### Session 2026-07-01

- Q: Which source of truth should define "in-scope core and addon components" for HA requirements? → A: All components managed by repository roles/playbooks, regardless of inventory enablement.
- Q: When HA expectations are not met after provisioning, what should the default enforcement behavior be? → A: Fail the playbook run (hard failure).
- Q: How should minimum HA targets (such as replica counts) be defined across in-scope components? → A: Component-specific minimum targets documented for each managed component, managed at the same top-level location as corresponding component versions.
- Q: For SC-003, how should "critical in-scope services" be defined? → A: An explicit critical-component subset listed in the spec.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enforce HA Defaults For HA Clusters (Priority: P1)

As a platform operator, I want core and addon components to automatically use high availability settings when I provision a high availability cluster so that service continuity is maintained during node failure or maintenance.

**Why this priority**: This is the primary value of the feature and directly affects cluster resilience.

**Independent Test**: Can be fully tested by provisioning a cluster with 3 or more servers and verifying each in-scope core/addon component runs with HA-aligned deployment settings.

**Acceptance Scenarios**:

1. **Given** a cluster definition with 3 or more server nodes, **When** provisioning runs, **Then** each in-scope core/addon component is configured in HA mode according to repository policy.
2. **Given** an HA cluster where one server becomes unavailable, **When** workloads are evaluated, **Then** in-scope core/addon services remain available without manual reconfiguration.

---

### User Story 2 - Preserve Non-HA Behavior For Small Clusters (Priority: P2)

As a platform operator, I want single-node and non-HA clusters to keep their current resource-conscious behavior so that HA changes do not increase operational cost where HA is not required.

**Why this priority**: Prevents regressions in existing small-cluster scenarios while adding HA behavior where needed.

**Independent Test**: Can be fully tested by provisioning a non-HA cluster and confirming in-scope components do not incorrectly force HA settings.

**Acceptance Scenarios**:

1. **Given** a cluster with fewer than 3 server nodes, **When** provisioning runs, **Then** component settings remain aligned with non-HA defaults.
2. **Given** both HA and non-HA inventories, **When** they are provisioned, **Then** resulting component availability settings differ appropriately by cluster topology.

---

### User Story 3 - Make HA Expectations Explicit (Priority: P3)

As a maintainer, I want clear documentation of HA behavior and minimum replica expectations for in-scope components so that contributors can update and validate configurations consistently.

**Why this priority**: Clear expectations reduce configuration drift and review ambiguity over time.

**Independent Test**: Can be fully tested by reviewing documentation and validating that every in-scope component has an explicit HA expectation and topology trigger.

**Acceptance Scenarios**:

1. **Given** the documented HA component list, **When** a contributor reviews it, **Then** they can determine the required behavior for HA and non-HA topologies without external clarification.
2. **Given** a change to an in-scope component, **When** it is reviewed, **Then** the documented HA expectation can be used as objective acceptance criteria.

### Edge Cases

- A component supports HA but has strict quorum or anti-affinity constraints that may not be satisfiable in minimally sized HA clusters.
- A component is deployed only when enabled by inventory variables; HA behavior must be applied only when that component is enabled.
- Existing clusters may already run with manually customized replica counts; topology-based defaults must not overwrite explicitly defined operator overrides.
- Addon installation order may cause temporary unavailability during initial rollout; final steady-state must still meet HA expectations.
- If HA expectations are unmet for any enabled in-scope component, execution fails and reports the violating component and expected target.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST classify a cluster as high availability when inventory defines 3 or more server nodes.
- **FR-002**: For high availability clusters, the system MUST apply high availability deployment settings to all in-scope core and addon components.
- **FR-003**: For clusters that are not high availability, the system MUST preserve current non-HA defaults unless an operator explicitly sets different values.
- **FR-004**: The system MUST define and document minimum availability expectations for each in-scope component.
- **FR-005**: The system MUST allow explicit operator overrides for component availability settings and MUST preserve those overrides during provisioning.
- **FR-006**: The system MUST validate that configured HA expectations are met after provisioning and report any component that does not meet its expected availability target.
- **FR-007**: If any enabled in-scope component in an HA cluster does not meet its documented HA expectation, the run MUST fail with a clear failure reason.
- **FR-008**: The system MUST keep HA behavior consistent across core lifecycle flows, including initial provisioning, scale operations, and upgrades.
- **FR-009**: The system MUST define HA expectations for all core and addon components currently managed by repository roles and playbooks, including components not enabled in a given inventory.
- **FR-010**: The system MUST apply HA behavior only to components that are enabled for deployment in the target inventory while preserving documented expectations for disabled components.
- **FR-011**: The system MUST define component-specific minimum HA targets for each in-scope managed component.
- **FR-012**: Component-specific minimum HA targets MUST be managed in the same top-level configuration location as the corresponding component version definitions.
- **FR-013**: The specification MUST define an explicit critical-component subset used for resilience and availability validation scenarios.
- **FR-014**: The critical-component subset for resilience validation consists of k3s control plane server service, kube-vip, and Traefik.

### Key Entities *(include if feature involves data)*

- **Cluster Topology Profile**: Captures whether a target cluster is HA or non-HA based on server-node count and relevant inventory traits.
- **Component Availability Policy**: Defines expected availability behavior for a managed component by topology, including component-specific minimum HA targets and their top-level configuration location.
- **Critical Component Subset**: Explicit list of managed components used for resilience validation scenarios.
- **Operator Availability Override**: User-provided settings that intentionally adjust component availability behavior from defaults.
- **Availability Validation Result**: Outcome record showing whether each in-scope component met its expected HA or non-HA target after execution.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of in-scope components in HA clusters meet their documented availability expectations after provisioning completes.
- **SC-002**: In validation runs covering both HA and non-HA inventories, 100% of components apply the correct topology-specific availability behavior and meet their documented component-specific minimum HA targets.
- **SC-003**: During simulated single-node disruption in an HA cluster, all components in the explicit critical-component subset remain available for at least 99% of requests over the test window.
- **SC-004**: At least 90% of maintainers reviewing component configuration changes report that HA expectations are clear and testable using repository documentation alone.

## Assumptions

- HA classification is based on inventory-defined server node count, with 3 or more server nodes treated as HA.
- In-scope coverage is determined by repository-managed roles/playbooks as the canonical source, even when some components are disabled in a specific inventory.
- Component-specific minimum HA targets are maintained in the same top-level configuration location as corresponding component versions.
- Existing operator-defined overrides are authoritative and should take precedence over topology-based defaults.
