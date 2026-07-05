# Feature Specification: Unified Upgrade Workflow

**Feature Branch**: `005-unified-upgrade-workflow`

**Created**: 2026-07-05

**Status**: Draft

**Input**: User description: "Refactor the upgrade process so installation and upgrades use the same user-level workflow via a single top-level playbook that determines component order, dependencies, and what needs updating."

## Clarifications

### Session 2026-07-05

- Q: When the operator sets a component version lower than currently deployed (downgrade), what should the system do? → A: Block downgrades by default with a clear error; require an explicit override variable to proceed.
- Q: How should the system detect what versions are currently deployed on the cluster? → A: Query the live cluster at runtime (e.g., k3s --version on nodes, helm list for add-ons).
- Q: How should the component dependency/compatibility data be defined? → A: Variables in group_vars/all.yml defining max/min version constraints per component pair.
- Q: When a node is offline or unreachable during an upgrade run, what should the system do? → A: Stop the entire upgrade with a clear error identifying the unreachable node(s).
- Q: What level of operator feedback should the playbook provide during execution? → A: Print a summary of the computed upgrade plan (which components, in what order) before executing, then standard Ansible output.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Single Command Deployment and Upgrade (Priority: P1)

As a cluster operator, I want to run one top-level playbook for both initial deployment and upgrades so that I don't need to remember different workflows or risk executing steps out of order.

**Why this priority**: This is the core value proposition — eliminating the fragmented multi-playbook workflow that creates risk of operator error and inconsistent cluster state.

**Independent Test**: Can be fully tested by running the single playbook against a fresh cluster (install path) and then re-running with updated version variables (upgrade path), verifying the cluster reaches the desired state in both cases.

**Acceptance Scenarios**:

1. **Given** a fresh set of provisioned hosts with no k3s installed, **When** the operator runs the unified playbook with desired component versions, **Then** k3s is installed, nodes join the cluster, and all specified add-ons are deployed.
2. **Given** an existing running cluster at version X, **When** the operator updates version variables and re-runs the unified playbook, **Then** only components with changed versions are upgraded in the correct dependency order.
3. **Given** an existing cluster where only Rancher version is changed, **When** the operator runs the unified playbook, **Then** only Rancher is upgraded and k3s and other components remain untouched.

---

### User Story 2 - Dependency-Aware Upgrade Ordering (Priority: P1)

As a cluster operator, I want the playbook to automatically determine the correct order of operations based on component dependencies so that upgrades don't fail due to version incompatibilities.

**Why this priority**: Incorrect ordering (e.g., upgrading k3s before Rancher when the existing Rancher version is incompatible with the new k3s) is the primary cause of failed upgrades and broken clusters. This is safety-critical.

**Independent Test**: Can be tested by specifying a new Rancher version alongside a newer k3s version, running the unified playbook, and verifying Rancher is upgraded before k3s.

**Acceptance Scenarios**:

1. **Given** an existing cluster with Rancher 2.8 on k3s v1.28, **When** the operator sets Rancher to 2.9 (which supports k3s v1.29) and k3s to v1.29, **Then** Rancher is upgraded first, followed by k3s on all nodes, since Rancher defines the maximum compatible k3s version.
2. **Given** an existing cluster, **When** the operator changes only the k3s version, **Then** k3s is upgraded on servers first (one at a time), then agents, with no changes to add-ons.
3. **Given** component dependencies are defined, **When** the operator requests an upgrade that would violate dependency constraints (e.g., k3s version exceeds what the current Rancher supports), **Then** the playbook fails early with a clear error message explaining the conflict before making any changes.

---

### User Story 3 - Selective Component Upgrades (Priority: P2)

As a cluster operator, I want to specify which components to upgrade and have the playbook only affect those components so that I can perform targeted maintenance without risk to unrelated services.

**Why this priority**: Operators often need to upgrade a single add-on or k3s itself without touching other components. Limiting the blast radius reduces risk.

**Independent Test**: Can be tested by changing only one component version variable and verifying through Ansible check mode and actual execution that only that component's tasks run.

**Acceptance Scenarios**:

1. **Given** a running cluster with cert-manager, traefik, and Rancher, **When** the operator updates only the cert-manager version, **Then** only cert-manager tasks execute and all other components are skipped.
2. **Given** a running cluster, **When** no version variables have changed from what is deployed, **Then** the playbook reports no changes needed and makes no modifications (idempotent no-op).

---

### User Story 4 - Safe Rolling Upgrades for k3s Nodes (Priority: P2)

As a cluster operator, I want k3s upgrades to proceed in a safe rolling fashion (servers first, one at a time, then agents) so that cluster availability is maintained during the upgrade.

**Why this priority**: Uncoordinated node upgrades can cause quorum loss and workload disruption. Rolling upgrades are essential for HA clusters.

**Independent Test**: Can be tested with a multi-node cluster by upgrading k3s and verifying nodes are upgraded sequentially with health checks between each.

**Acceptance Scenarios**:

1. **Given** a 3-server HA cluster, **When** a k3s upgrade is performed, **Then** servers are upgraded one at a time with a health check confirming cluster health before proceeding to the next.
2. **Given** a cluster with 5 agent nodes, **When** agents are being upgraded, **Then** agents are upgraded in a controlled rolling manner to maintain workload availability.
3. **Given** a node upgrade fails the health check, **When** the failure is detected, **Then** the playbook stops and reports the failure without proceeding to additional nodes.

---

### Edge Cases

- What happens when the operator downgrades a component version? → System blocks with a clear error unless an explicit override variable (e.g., `allow_downgrade: true`) is set.
- How does the system handle a partially failed previous upgrade (cluster in mixed-version state)? → System queries live state, so it detects the actual versions on each node/component and converges toward the desired state regardless of prior failures.
- What happens when a component's dependency information is unavailable or undefined?
- How does the system behave when the cluster is unreachable or a node is offline during upgrade? → System stops the entire upgrade with a clear error identifying the unreachable node(s); no partial upgrades proceed.
- What happens when the operator upgrades k3s to a version incompatible with the currently deployed Rancher version?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single top-level playbook that handles both initial cluster deployment and component upgrades.
- **FR-002**: System MUST detect which components have version changes by querying the live cluster at runtime (e.g., `k3s --version` on nodes, `helm list` for Helm-deployed add-ons) and comparing against desired versions; only components with differences are processed.
- **FR-003**: System MUST define and enforce a dependency graph between components using version constraint variables in `group_vars/all.yml` (max/min version pairs) to determine upgrade ordering.
- **FR-004**: System MUST upgrade k3s server nodes sequentially (one at a time) with health validation between each node.
- **FR-005**: System MUST upgrade k3s agent nodes in a controlled rolling fashion after all servers are upgraded.
- **FR-006**: System MUST fail early with a clear error message if requested versions violate dependency constraints, before making any changes to the cluster.
- **FR-007**: System MUST remain fully idempotent — re-running the playbook with no version changes produces no modifications.
- **FR-008**: System MUST preserve the ability to run individual component playbooks (cluster-core, cluster-addons) for operators who prefer granular control.
- **FR-009**: System MUST validate that the target k3s version does not exceed the maximum version supported by the target Rancher version when both are specified.
- **FR-010**: System MUST cordon and drain nodes before upgrading k3s on each node, then uncordon after successful upgrade.
- **FR-011**: System MUST support upgrading Rancher and k3s together in a single playbook run, with Rancher upgraded before k3s to respect compatibility constraints.
- **FR-012**: System MUST block version downgrades by default with a clear error message; an explicit override variable (e.g., `allow_downgrade: true`) MUST be required to proceed with a downgrade.
- **FR-013**: System MUST stop the entire upgrade and report an error identifying the unreachable node(s) if any target node is offline or unreachable at the start of or during the upgrade.
- **FR-014**: System MUST print a summary of the computed upgrade plan (components to be changed, execution order, and target versions) before executing any changes, then proceed with standard Ansible task output.

### Key Entities

- **Component**: A deployable unit with a version, dependencies, and an associated role/playbook (e.g., k3s, Rancher, cert-manager, traefik, kube-vip, synology-csi, multus).
- **Dependency Graph**: A directed acyclic graph defining ordering constraints between components (e.g., k3s depends on Rancher being upgraded first, since Rancher defines the maximum compatible k3s version).
- **Upgrade Plan**: The computed set of components that need changes and their execution order for a given run.
- **Health Check**: A validation step confirming cluster/node health at a specific point during the upgrade sequence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Operators can deploy a fresh cluster and upgrade an existing cluster using the same single command with no workflow differences.
- **SC-002**: A combined Rancher + k3s upgrade completes successfully with Rancher upgraded before k3s in a single playbook run without operator intervention.
- **SC-003**: When only one component version changes, no other component's tasks execute (zero unnecessary changes).
- **SC-004**: A k3s upgrade across a 3-server, 5-agent cluster maintains cluster availability throughout (no quorum loss, workloads remain accessible).
- **SC-005**: An upgrade with incompatible version constraints is rejected within 30 seconds with a clear error message, with no changes applied to the cluster.
- **SC-006**: Re-running the unified playbook with no version changes completes in under 2 minutes with zero modifications reported.

## Assumptions

- The existing role structure (k3s-server, k3s-agent, k3s-common, cert-manager, traefik, kube-vip, rancher, etc.) will be preserved and reused; the unified playbook orchestrates these roles rather than replacing them.
- Component version compatibility information (e.g., which k3s versions are compatible with which Rancher versions) will be maintained as variables in `group_vars/all.yml` defining max/min version constraints per component pair.
- Operators are responsible for setting correct target versions in their inventory/group variables; the system validates constraints but does not auto-select versions.
- The cluster has been initially deployed using this project's playbooks (the system does not support upgrading clusters provisioned by other tools).
- Node drain behavior follows standard Kubernetes semantics and requires workloads to have appropriate disruption budgets for zero-downtime guarantees.
- The existing individual playbooks (cluster-core.yml, cluster-addons.yml) will continue to work for operators who prefer the current granular approach.
