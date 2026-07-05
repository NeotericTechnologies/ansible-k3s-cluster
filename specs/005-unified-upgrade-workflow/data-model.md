# Data Model: Unified Upgrade Workflow

**Feature**: 005-unified-upgrade-workflow
**Date**: 2026-07-05

## Entities

### Component

A deployable unit managed by the unified playbook.

| Field | Type | Description |
|-------|------|-------------|
| name | string | Component identifier (e.g., `k3s`, `rancher`, `cert_manager`) |
| version_var | string | Ansible variable name holding desired version (e.g., `k3s_version`, `rancher_version`) |
| enabled_var | string | Ansible variable name for enablement flag (e.g., `rancher_enabled`); `null` for k3s (always enabled) |
| detect_method | enum | How to detect live version: `k3s_binary`, `helm_release`, `manifest_label` |
| detect_args | dict | Arguments for detection (e.g., helm release name, namespace, label selector) |
| upgrade_priority | int | Execution order (lower = earlier). Rancher=10, k3s=20, add-ons=30+ |
| play_file | string | Relative path to the play/include that handles this component |

### Component Registry (variable structure)

```yaml
# Defined in a vars file loaded by the orchestrator
upgrade_components:
  - name: rancher
    version_var: rancher_version
    enabled_var: rancher_enabled
    detect_method: helm_release
    detect_args:
      release_name: rancher
      namespace: cattle-system
    upgrade_priority: 10
    play_file: includes/upgrade-rancher.yml

  - name: k3s
    version_var: k3s_version
    enabled_var: null  # always enabled
    detect_method: k3s_binary
    detect_args: {}
    upgrade_priority: 20
    play_file: includes/upgrade-k3s-rolling.yml

  - name: cert_manager
    version_var: cert_manager_version
    enabled_var: cert_manager_enabled
    detect_method: helm_release
    detect_args:
      release_name: cert-manager
      namespace: cert-manager
    upgrade_priority: 30
    play_file: includes/upgrade-addon.yml

  - name: traefik
    version_var: traefik_version
    enabled_var: traefik_enabled
    detect_method: helm_release
    detect_args:
      release_name: traefik
      namespace: kube-system
    upgrade_priority: 31
    play_file: includes/upgrade-addon.yml

  - name: rancher_monitoring
    version_var: rancher_monitoring_version
    enabled_var: rancher_monitoring_enabled
    detect_method: helm_release
    detect_args:
      release_name: rancher-monitoring
      namespace: cattle-monitoring-system
    upgrade_priority: 32
    play_file: includes/upgrade-addon.yml

  - name: kube_vip
    version_var: kube_vip_version
    enabled_var: kube_vip_enabled
    detect_method: manifest_label
    detect_args:
      label_selector: "app.kubernetes.io/name=kube-vip"
      namespace: kube-system
    upgrade_priority: 15  # After Rancher, before k3s (deployed on control-plane)
    play_file: includes/upgrade-kube-vip.yml

  - name: multus
    version_var: multus_version
    enabled_var: multus_enabled
    detect_method: manifest_label
    detect_args:
      label_selector: "app=multus"
      namespace: kube-system
    upgrade_priority: 33
    play_file: includes/upgrade-addon.yml

  - name: synology_csi
    version_var: synology_csi_version
    enabled_var: synology_csi_enabled
    detect_method: helm_release
    detect_args:
      release_name: synology-csi
      namespace: synology-csi
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
| components_skipped | list[string] | Components with no version change or disabled |
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
