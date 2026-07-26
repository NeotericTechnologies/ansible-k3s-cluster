# cilium Role

## Purpose

Install and configure Cilium as the k3s cluster CNI, replacing Flannel. Required when `kube_vip_egress_enabled: true` (see `kube-vip` role) since egress gateway steering depends on `CiliumEgressGatewayPolicy`. This role owns the `CiliumEgressGatewayPolicy` CR (it is a Cilium CRD, only registered once the Helm chart is installed); the kube-vip role owns the corresponding egress LoadBalancer `Service`.

## Requirements

- k3s server(s) started with `--flannel-backend=none --disable-network-policy` (set via `k3s_server_extra_args` when `cilium_enabled: true` — see `ansible/roles/k3s-server`)
- Helm available on the control node (via `kubernetes.core.helm` collection)
- CNI decision (Flannel vs Cilium) MUST be made at initial cluster deployment. Migrating a live cluster from Flannel to Cilium requires a coordinated rolling restart of `k3s-server` on all control-plane nodes and cleanup of Flannel artifacts (interfaces, CNI config) — not automated by this role.

## Role Variables

```yaml
cilium_enabled: false                       # Master enable flag; replaces Flannel when true
cilium_version: ""                          # REQUIRED when enabled — pin the exact Cilium version (e.g. "v1.16.6" or "1.16.6"), no "latest"
cilium_namespace: "kube-system"
cilium_helm_repo: "https://helm.cilium.io/"
cilium_helm_release_name: "cilium"
cilium_helm_values: {}                       # Additional Helm values merged with role defaults
cilium_egress_gateway_enabled: false         # Sets egressGateway.enabled in Helm values; auto-set true when kube_vip_egress_enabled: true
cilium_cni_conf_path: "/var/lib/rancher/k3s/agent/etc/cni/net.d"  # Where Cilium writes CNI config for k3s kubelet/Multus
cilium_cni_bin_path: "/var/lib/rancher/k3s/data/current/bin"       # Where Cilium installs CNI binaries on k3s
cilium_kubelet_cni_bin_path: "/var/lib/rancher/k3s/data/cni"       # Stable kubelet plugin lookup path (symlink destination)
```

## Role Tasks

- Asserts `cilium_version` is set (fails fast otherwise)
- Adds the Cilium Helm repository
- Auto-enables `egressGateway.enabled` in Helm values when `kube_vip_egress_enabled: true` (kube-vip role)
- Installs/upgrades the Cilium Helm release, pinned to `cilium_version` (the official chart is versioned 1:1 with the Cilium app version, without a leading "v" — the role strips it automatically when resolving the chart version, so either "v1.16.6" or "1.16.6" works)
- Enforces k3s CNI paths via Helm values (`cni.confPath`, `cni.binPath`) for Cilium install and multus compatibility
- Reconciles a symlink from `{{ cilium_kubelet_cni_bin_path }}/cilium-cni` to `{{ cilium_cni_bin_path }}/cilium-cni` so kubelet always finds the plugin in k3s's stable lookup directory
- Removes stale `10-flannel.conflist` files from common k3s CNI directories to avoid Multus auto-config selecting legacy Flannel bridge config after Cilium migration
- Waits for the Cilium DaemonSet to report all pods ready
- Restarts `kube-multus-ds` (when `multus_enabled: true`) so Multus re-autodetects the active primary CNI config
- Applies the `CiliumEgressGatewayPolicy` CR when `kube_vip_egress_enabled: true` (after the DaemonSet-ready wait, so the CRD is guaranteed to exist); uses `kube_vip_egress_*` variables owned by the kube-vip role and mirrored in `ansible/group_vars/all.yml`

## Dependencies

- k3s-server role (must be deployed first, with Flannel disabled when `cilium_enabled: true`)

## Example Playbook

```yaml
- hosts: k3s_servers[0]
  roles:
    - role: cilium
```

## Verification

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get ciliumegressgatewaypolicies  # if egress gateway enabled
```
