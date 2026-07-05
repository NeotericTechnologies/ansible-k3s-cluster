# Quickstart Validation: Unified Upgrade Workflow

**Feature**: 005-unified-upgrade-workflow
**Date**: 2026-07-05

## Prerequisites

- Ansible control host with access to cluster nodes (SSH keys configured)
- Inventory file with `k3s_servers` and `k3s_agents` groups defined
- `group_vars/all.yml` with component versions and `component_compatibility` defined
- For upgrade scenarios: an existing cluster deployed via this project's playbooks

## Scenario 1: Fresh Install via Unified Playbook

**Purpose**: Verify the single playbook handles initial deployment (SC-001).

```bash
# Set desired versions in group_vars/all.yml (already done by default)
# Run the unified playbook
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Upgrade plan summary shows all components as "install" action
- k3s installed on all nodes, cluster operational
- Enabled add-ons deployed
- `kubectl get nodes` shows all nodes Ready

## Scenario 2: Idempotent No-Op Re-run

**Purpose**: Verify re-run with no changes produces no modifications (SC-006).

```bash
# Run again immediately after Scenario 1
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Upgrade plan summary: "No changes needed"
- 0 changed tasks
- Completes in under 2 minutes

## Scenario 3: Combined Rancher + k3s Upgrade

**Purpose**: Verify correct ordering — Rancher before k3s (SC-002).

```bash
# Update versions in group_vars/all.yml:
#   rancher_version: "2.9.0"
#   k3s_version: "v1.29.2+k3s1"
# Ensure component_compatibility.rancher.k3s_max_version >= v1.29.2+k3s1

ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Plan summary shows: Rancher (priority 10) before k3s (priority 20)
- Rancher Helm chart upgraded first
- k3s servers upgraded one at a time (with cordon/drain/uncordon)
- k3s agents upgraded one at a time (with cordon/drain/uncordon)
- All other components skipped

## Scenario 4: Selective Add-on Upgrade

**Purpose**: Verify only changed component executes (SC-003).

```bash
# Update only cert-manager version:
#   cert_manager_version: "v1.14.0"

ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Plan summary shows only cert-manager as "upgrade"
- Only cert-manager tasks execute
- k3s, Rancher, traefik, etc. all skipped

## Scenario 5: Constraint Violation (Fail-Fast)

**Purpose**: Verify incompatible versions are rejected before changes (SC-005).

```bash
# Set k3s to a version beyond Rancher's max:
#   k3s_version: "v1.31.0+k3s1"
# With component_compatibility.rancher.k3s_max_version = "v1.30.99+k3s99"

ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Fails within 30 seconds
- Error: "k3s v1.31.0+k3s1 exceeds max supported by rancher: v1.30.99+k3s99"
- No changes applied to cluster

## Scenario 6: Downgrade Blocked

**Purpose**: Verify downgrade detection and blocking.

```bash
# Set k3s_version to a version lower than currently deployed
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

**Expected outcome**:
- Fails with: "Downgrade detected for k3s: {live} → {desired}. Set allow_downgrade=true to proceed"
- No changes applied

```bash
# Override to allow downgrade
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml \
  -e "allow_downgrade=true"
```

**Expected outcome**:
- Proceeds with the downgrade using the same rolling process

## Scenario 7: Existing Playbooks Still Work

**Purpose**: Verify backward compatibility (FR-008).

```bash
# These must continue to work independently
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-addons.yml
```

**Expected outcome**:
- Both playbooks execute successfully with no behavioral changes
- Same idempotent behavior as before this feature

## Validation Checklist

- [ ] SC-001: Same command for install and upgrade
- [ ] SC-002: Rancher upgraded before k3s
- [ ] SC-003: Only changed components execute
- [ ] SC-004: Cluster available throughout rolling upgrade
- [ ] SC-005: Constraint violation rejected in <30s
- [ ] SC-006: No-op completes in <2min with 0 changes
