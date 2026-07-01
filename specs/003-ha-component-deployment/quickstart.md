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
