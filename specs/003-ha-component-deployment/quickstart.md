# Quickstart: Validate HA Component Deployment

This guide validates topology-aware HA behavior for repository-managed components.

## Prerequisites

- Ansible control host with required collections installed.
- Access to inventories containing both:
  - HA topology (`k3s_servers` count >= 3)
  - Non-HA topology (`k3s_servers` count < 3)
- Configured top-level component versions and corresponding HA minimum target variables in:
  - `ansible/group_vars/all.yml`
  - optional inventory overrides in inventory `group_vars/all.yml`

## 1) Confirm Policy Inputs

1. Verify component version variables are present in top-level `group_vars`.
2. Verify each managed component has a component-specific HA minimum target variable at the same top-level scope.
3. Verify optional operator overrides are defined only where intended.

Reference:
- Policy entities and rules: [data-model.md](./data-model.md)

## 2) Validate HA Provisioning Behavior

1. Run core provisioning on an HA inventory.
   - `ansible-playbook -i <ha-inventory> ansible/playbooks/cluster-core.yml`
2. Run addon deployment on the same HA inventory.
   - `ansible-playbook -i <ha-inventory> ansible/playbooks/cluster-addons.yml`
3. Confirm enabled in-scope components meet their documented HA minimum targets.

Expected outcome:
- All enabled components satisfy HA targets.
- If any enabled component misses target, run fails with component-specific reason.

Reference:
- Enforcement and failure behavior: [contracts/ha-lifecycle-contracts.md](./contracts/ha-lifecycle-contracts.md)

## 3) Validate Non-HA Preservation

1. Run the same lifecycle commands with a non-HA inventory.
2. Confirm existing non-HA defaults are preserved unless explicit overrides are set.

Expected outcome:
- No unintended HA forcing on non-HA topology.

## 4) Validate Scale Consistency

1. Modify inventory to add/remove nodes.
2. Execute:
   - `ansible-playbook -i <inventory> ansible/playbooks/scale-nodes.yml`
3. Re-check topology classification and component target compliance.

Expected outcome:
- Post-scale topology is reflected correctly.
- HA targets remain satisfied when resulting topology is HA.

## 5) Validate Upgrade Consistency

1. Set target `k3s_version`.
2. Execute:
   - `ansible-playbook -i <inventory> -e k3s_version=<target> ansible/playbooks/upgrade-k3s.yml`
3. Validate component availability targets remain compliant after upgrade.

Expected outcome:
- Upgrade completes and topology-aware policy remains enforced.

## 6) Validate Critical Subset Resilience

1. On HA topology, execute a single-node disruption test window.
2. Measure request availability for critical subset:
   - k3s control plane server service
   - kube-vip
   - Traefik

Expected outcome:
- Each critical component remains available for >=99% of requests.

## 7) Baseline Quality Gates

Run repository quality checks:

- `ansible-lint`
- `ansible-playbook --check -i <inventory> ansible/playbooks/cluster-core.yml`
- `ansible-playbook --check -i <inventory> ansible/playbooks/cluster-addons.yml`

Expected outcome:
- Lint and check-mode pass with no HA policy regressions.

## 8) Documentation Traceability Checklist

Use this checklist to confirm documentation coverage for all managed components:

- [x] `k3s-common` mapped to topology trigger and HA expectation
- [x] `k3s-server` mapped to topology trigger and HA expectation
- [x] `k3s-agent` mapped to topology trigger and HA expectation
- [x] `kube-vip` mapped to topology trigger and HA expectation
- [x] `cert-manager` mapped to topology trigger and HA expectation
- [x] `multus` mapped to topology trigger and HA expectation
- [x] `traefik` mapped to topology trigger and HA expectation
- [x] `rancher` mapped to topology trigger and HA expectation
- [x] `rancher-monitoring` mapped to topology trigger and HA expectation
- [x] `synology-csi` mapped to topology trigger and HA expectation

Coverage references:

| Component | Topology Trigger Coverage | HA Expectation Coverage |
|-----------|----------------------------|-------------------------|
| k3s-common | `resolve-ha-policy.yml` topology classification and policy map | `validate-ha-targets.yml` assertions and hard-fail behavior |
| k3s-server | `k3s_servers` count >= 3 policy trigger | Control-plane minimum target and validation assertions |
| k3s-agent | Non-HA preservation and lifecycle consistency sections | Scale/upgrade consistency requirements for managed lifecycle |
| kube-vip | Explicit topology trigger in expectation matrix | Minimum available replicas in HA matrix and validation |
| cert-manager | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and validation |
| multus | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and validation |
| traefik | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and critical subset checks |
| rancher | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and validation |
| rancher-monitoring | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and validation |
| synology-csi | Enabled + HA topology trigger in matrix | Minimum available replicas in HA matrix and validation |

Primary references:
- `docs/ansible-k3s-baseline.md` (HA expectation matrix and policy variable table)
- `docs/ansible-structure.md` (same-scope rule and maintainer workflow)
- `contracts/ha-lifecycle-contracts.md` (topology resolution, enforcement, lifecycle consistency)

## 9) Validation Record

Capture implementation validation evidence here after running the full flow:

- HA inventory run result:
- Non-HA inventory run result:
- Scale operation validation result:
- Upgrade operation validation result:
- Critical subset disruption test result:
