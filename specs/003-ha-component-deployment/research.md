# Phase 0 Research: HA Component Deployment

## R-001: HA Topology Detection Source

- **Decision**: Classify a target cluster as HA when inventory defines three or more hosts in `k3s_servers`.
- **Rationale**: The repository already uses inventory groups as the source of role behavior (`k3s_servers`, `k3s_agents`) in lifecycle playbooks, so topology detection from inventory is consistent and deterministic.
- **Alternatives considered**:
  - **Runtime Kubernetes node-role discovery only**: Rejected because behavior must be decided during provisioning before full cluster convergence.
  - **Manual `ha_mode` toggle only**: Rejected because it can drift from actual server count and would violate explicit topology rule in the spec.

## R-002: In-Scope Component Source of Truth

- **Decision**: Define in-scope components from all repository-managed roles and playbooks, regardless of whether a component is enabled in a specific inventory.
- **Rationale**: This matches the clarified requirement and ensures every managed component has documented HA expectations, while still applying behavior only when enabled.
- **Alternatives considered**:
  - **Inventory-enabled components only**: Rejected because documentation and policy coverage would vary by environment and become incomplete.
  - **Core-only scope**: Rejected because the feature explicitly includes addons.

## R-003: Placement of HA Minimum Target Variables

- **Decision**: Store component-specific HA minimum target variables at the same top-level scope as corresponding version variables in `ansible/group_vars/all.yml`, with environment overrides in inventory-level `group_vars/all.yml` where needed.
- **Rationale**: Repository version variables are already centralized at this level (`k3s_version`, `cert_manager_version`, `multus_version`, `rancher_version`, etc.), so placing HA target variables beside them gives a single, auditable control surface.
- **Alternatives considered**:
  - **Role-local defaults only**: Rejected because it scatters policy and weakens environment-level governance.
  - **Dedicated separate HA config file**: Rejected because it breaks the requested co-location with version definitions.

## R-004: Validation Enforcement Mode for Unmet HA Targets

- **Decision**: Enforce hard-fail behavior: if any enabled in-scope component in HA topology does not meet its documented target, the run fails with explicit component-level reasons.
- **Rationale**: Hard-fail prevents silent resilience regressions and gives deterministic CI/CD and operator outcomes.
- **Alternatives considered**:
  - **Warn-only**: Rejected because it allows drift to production.
  - **Warn-by-default with optional fail**: Rejected because the clarified requirement sets fail as default behavior.

## R-005: Critical-Component Subset for Disruption Validation

- **Decision**: Use an explicit critical subset defined in the spec: `k3s control plane server service`, `kube-vip`, and `Traefik`.
- **Rationale**: These components represent API control-plane continuity, front-door traffic continuity, and core ingress availability during single-node disruption tests.
- **Alternatives considered**:
  - **All components critical**: Rejected due to noisy and brittle disruption checks for optional addons.
  - **Runtime environment-derived subset**: Rejected because it reduces repeatability and comparability across runs.

## R-006: Lifecycle Consistency Pattern

- **Decision**: Apply the same HA policy model and validation contracts across `cluster-core.yml`, `cluster-addons.yml`, `scale-nodes.yml`, and `upgrade-k3s.yml`.
- **Rationale**: The spec requires consistent behavior across provisioning, scaling, and upgrades; these are the repository lifecycle entrypoints.
- **Alternatives considered**:
  - **Provision-time only enforcement**: Rejected because scale/upgrade operations can invalidate HA state later.
  - **Addon-only enforcement**: Rejected because core components are part of the critical subset and must be included.

## R-007: Default Non-HA Preservation Strategy

- **Decision**: Keep existing non-HA behavior unchanged for inventories with fewer than three server nodes unless explicit overrides are set.
- **Rationale**: This preserves compatibility for single-node and small non-HA clusters and satisfies backward-compatibility requirements.
- **Alternatives considered**:
  - **Always enforce multi-replica defaults**: Rejected due to resource/cost regressions and contradiction with spec user story 2.
