# Lifecycle Contracts: Unified Upgrade Workflow

**Feature**: 005-unified-upgrade-workflow
**Date**: 2026-07-05

## Playbook Interface Contract

### Entry Point

```
ansible-playbook -i <inventory> ansible/playbooks/site.yml
```

### Behavior Contract

| Condition | Behavior |
|-----------|----------|
| Fresh hosts (no k3s installed) | Full install path: k3s core → kube-vip → enabled add-ons |
| No version changes detected | No-op with summary: "No changes needed" |
| k3s version changed | Rolling k3s upgrade: servers serial:1 → agents serial:1 |
| Rancher version changed | Rancher Helm upgrade only |
| Rancher + k3s versions changed | Rancher upgrade first, then rolling k3s upgrade |
| Add-on version changed | Only that add-on's role executes |
| Downgrade detected | FAIL unless `allow_downgrade: true` |
| Constraint violation | FAIL with explanation before any changes |
| Node unreachable | FAIL immediately identifying unreachable node(s) |

### Variables Contract

All existing variables remain unchanged. New variables introduced:

| Variable | Default | Description |
|----------|---------|-------------|
| `component_compatibility` | (see data-model.md) | Version constraint map in group_vars/all.yml |
| `allow_downgrade` | `false` | Override to permit version decreases |
| `upgrade_drain_timeout` | `300` | Seconds to wait for node drain before failing |
| `upgrade_node_ready_timeout` | `300` | Seconds to wait for node Ready after upgrade |
| `upgrade_pause_between_nodes` | `10` | Seconds to pause between sequential node upgrades |

### Output Contract

Before executing changes, the playbook MUST print:

```
Upgrade Plan:
  Components to upgrade:
    - rancher: 2.8.0 → 2.9.0
    - k3s: v1.28.5+k3s1 → v1.29.2+k3s1
  Execution order:
    1. rancher (Helm upgrade)
    2. k3s servers (rolling: node1, node2, node3)
    3. k3s agents (rolling: worker1, worker2)
  Components unchanged: cert-manager, traefik, kube-vip
```

### Error Contract

All errors MUST be emitted before any changes are made (fail-fast):

| Error Code | Message Pattern | Cause |
|------------|-----------------|-------|
| CONSTRAINT_VIOLATION | "k3s {desired} exceeds max supported by rancher: {max}" | k3s version > rancher's k3s_max_version |
| DOWNGRADE_BLOCKED | "Downgrade detected for {component}: {live} → {desired}. Set allow_downgrade=true to proceed" | Version decrease without override |
| NODE_UNREACHABLE | "Cannot proceed: node(s) unreachable: {nodes}" | Ansible cannot connect to target host(s) |
| HEALTH_CHECK_FAILED | "Node {node} failed health check after upgrade. Stopping." | Node not Ready after upgrade |
| DRAIN_TIMEOUT | "Drain of {node} timed out after {timeout}s" | Workloads could not be evicted in time |

## Backward Compatibility Contract

| Existing Playbook | Status | Notes |
|-------------------|--------|-------|
| `cluster-core.yml` | PRESERVED | Continues to work independently for core-only operations |
| `cluster-addons.yml` | PRESERVED | Continues to work independently for add-on-only operations |
| `upgrade-k3s.yml` | DEPRECATED | Superseded by `site.yml`; remains functional but docs point to `site.yml` |
| `scale-nodes.yml` | UNCHANGED | Not part of unified workflow |

## Idempotency Contract

| Scenario | Expected Result |
|----------|-----------------|
| Run site.yml with no version changes | 0 changed tasks, completes in <2min |
| Run site.yml twice after a successful upgrade | Second run reports no changes |
| Run site.yml after a partially-failed upgrade | Detects actual state, converges remaining nodes |
