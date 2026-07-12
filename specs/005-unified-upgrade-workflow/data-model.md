# Data Model: Unified Upgrade Workflow

**Feature**: 005-unified-upgrade-workflow
**Date**: 2026-07-05

## Entities

### Component

A deployable unit managed by the unified playbook.

| Field | Type | Description |
|-------|------|-------------|
| name | string | Component identifier (e.g., `k3s_servers`, `k3s_agents`, `rancher`, `cert_manager`) |
| version_var | string | Ansible variable name holding desired version (e.g., `k3s_version`, `rancher_version`) |
| enabled_var | string | Ansible variable name for enablement flag (e.g., `rancher_enabled`); `null` for k3s_servers/k3s_agents (always enabled) |
| detect_method | enum | How to detect live version: `k3s_binary`, `helm_release`, `manifest_label` |
| detect_args | dict | Arguments for detection (e.g., helm release name, namespace, label selector) |
| fresh_install_priority | int | Execution order during fresh installs (lower = earlier). k3s_servers=5, kube-vip=10, k3s_agents=12, cert-manager=20, multus=21, traefik=22, rancher=23, rancher-monitoring=24, synology-csi=25 |
| upgrade_priority | int | Execution order during upgrades (lower = earlier). rancher=10, k3s_servers=15, kube-vip=20, k3s_agents=25, add-ons=30+ |
| play_file | string | Relative path to the play/include that handles this component |

**Priority Strategy**:
- **Fresh installs**: Deploy servers first (k3s_servers), then control-plane VIP (kube-vip), then agents (k3s_agents), then add-ons. Order: k3s_servers (5) → kube-vip (10) → k3s_agents (12) → cert-manager (20) → multus (21) → traefik (22) → rancher (23) → rancher-monitoring (24) → synology-csi (25). This ensures all control-plane nodes are ready and discoverable via VIP before workers join.
- **Upgrades**: Rancher first for compatibility with k3s versions (10), then k3s servers (15), then kube-vip (20), then k3s agents (25), then add-ons. k3s_servers must upgrade before agents to maintain control-plane quorum; kube-vip updates between them to reflect any server IP changes.

### Component Registry (variable structure)

**Note on k3s Decomposition**: Both `k3s_servers` and `k3s_agents` reference the same `version_var: k3s_version` (single desired version). This ensures servers and agents are always upgraded to the same k3s version; the orchestration logic (via `detect_args.group`) determines which node group to apply it to. Both components share the same `play_file` but pass different `node_role` context (`server` vs `agent`) during execution, allowing the same rolling-upgrade logic to work for both.

```yaml
# Defined in ansible/playbooks/includes/vars/component-registry.yml
upgrade_components:
  - name: rancher
    version_var: rancher_version
    enabled_var: rancher_enabled
    detect_method: helm_release
    detect_args:
      release_name: rancher
      namespace: cattle-system
    fresh_install_priority: 23
    upgrade_priority: 10
    play_file: includes/upgrade-rancher.yml

  - name: kube_vip
    version_var: kube_vip_version
    enabled_var: kube_vip_enabled
    detect_method: manifest_label
    detect_args:
      label_selector: "app.kubernetes.io/name=kube-vip"
      namespace: kube-system
    fresh_install_priority: 10
    upgrade_priority: 20
    play_file: includes/upgrade-kube-vip.yml

  - name: k3s_servers
    version_var: k3s_version
    enabled_var: null  # always enabled
    detect_method: k3s_binary
    detect_args:
      group: k3s_servers
    fresh_install_priority: 5
    upgrade_priority: 15
    play_file: includes/upgrade-k3s-rolling.yml

  - name: k3s_agents
    version_var: k3s_version
    enabled_var: null  # always enabled
    detect_method: k3s_binary
    detect_args:
      group: k3s_agents
    fresh_install_priority: 12
    upgrade_priority: 25
    play_file: includes/upgrade-k3s-rolling.yml

  - name: cert_manager
    version_var: cert_manager_version
    enabled_var: cert_manager_enabled
    detect_method: helm_release
    detect_args:
      release_name: cert-manager
      namespace: cert-manager
    fresh_install_priority: 20
    upgrade_priority: 30
    play_file: includes/upgrade-addon.yml

  - name: traefik
    version_var: traefik_version
    enabled_var: traefik_enabled
    detect_method: helm_release
    detect_args:
      release_name: traefik
      namespace: kube-system
    fresh_install_priority: 22
    upgrade_priority: 32
    play_file: includes/upgrade-addon.yml

  - name: rancher_monitoring
    version_var: rancher_monitoring_version
    enabled_var: rancher_monitoring_enabled
    detect_method: helm_release
    detect_args:
      release_name: rancher-monitoring
      namespace: cattle-monitoring-system
    fresh_install_priority: 24
    upgrade_priority: 33
    play_file: includes/upgrade-addon.yml

  - name: multus
    version_var: multus_version
    enabled_var: multus_enabled
    detect_method: manifest_label
    detect_args:
      label_selector: "app=multus"
      namespace: kube-system
    fresh_install_priority: 21
    upgrade_priority: 31
    play_file: includes/upgrade-addon.yml

  - name: synology_csi
    version_var: synology_csi_version
    enabled_var: synology_csi_enabled
    detect_method: helm_release
    detect_args:
      release_name: synology-csi
      namespace: synology-csi
    fresh_install_priority: 25
    upgrade_priority: 34
    play_file: includes/upgrade-addon.yml
```

### Component Compatibility (variable structure)

```yaml
# Defined in group_vars/all.yml
component_compatibility:
  rancher:
    k3s_max_version: "v1.30.99+k3s99"
    k3s_min_version: "v1.27.0+k3s1"
  cert_manager:
    k3s_min_version: "v1.25.0+k3s1"
```

### Upgrade Plan (runtime computed)

| Field | Type | Description |
|-------|------|-------------|
| components_to_upgrade | list[dict] | Components with version drift, sorted by `upgrade_priority` |
| components_unchanged | list[string] | Enabled components with no version change (`action: none`) |
| components_not_enabled | list[string] | Disabled components skipped from install/upgrade |
| constraint_violations | list[string] | Any constraint violations detected (empty if valid) |
| is_fresh_install | bool | True if k3s is not yet installed on any node |

### Detected State (runtime fact)

| Field | Type | Description |
|-------|------|-------------|
| component_name | string | Component identifier |
| live_version | string | Version currently deployed (or `not_installed`) |
| desired_version | string | Version from group_vars |
| action | enum | `install`, `upgrade`, `downgrade`, `none` |

## State Transitions

```
Component Lifecycle:
  not_installed → install → running@version
  running@version_A → upgrade → running@version_B (where B > A)
  running@version_A → downgrade → running@version_B (where B < A, requires allow_downgrade)
  running@version_A → none → running@version_A (no change detected)
```

## Validation Rules

1. If `action == downgrade` and `allow_downgrade != true` → FAIL
2. If k3s desired version > `component_compatibility.rancher.k3s_max_version` → FAIL
3. If k3s desired version < `component_compatibility.rancher.k3s_min_version` → FAIL
4. If a component has no entry in `component_compatibility`, it is treated as having no constraints (unconstrained components are always allowed) → explicit entry required for any component that has version dependencies
5. All components in `upgrade_components` registry MUST have an explicit `component_compatibility` entry (even if empty `{}`) to confirm constraints were intentionally evaluated
4. If k3s desired version < `component_compatibility.cert_manager.k3s_min_version` and cert_manager is being upgraded → FAIL
5. All nodes in target inventory must be reachable → FAIL if any unreachable
