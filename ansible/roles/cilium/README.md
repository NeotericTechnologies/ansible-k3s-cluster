# cilium Role

## Purpose

Install and configure Cilium as the k3s cluster CNI, replacing Flannel. Required when `kube_vip_egress_enabled: true` (see `kube-vip` role) since egress gateway steering depends on `CiliumEgressGatewayPolicy`.

## Requirements

- k3s server(s) started with `--flannel-backend=none --disable-network-policy` (set via `k3s_server_extra_args` when `cilium_enabled: true` — see `ansible/roles/k3s-server`)
- Helm available on the control node (via `kubernetes.core.helm` collection)
- CNI decision (Flannel vs Cilium) MUST be made at initial cluster deployment. Migrating a live cluster from Flannel to Cilium requires a coordinated rolling restart of `k3s-server` on all control-plane nodes and cleanup of Flannel artifacts (interfaces, CNI config) — not automated by this role.

## Role Variables

```yaml
cilium_enabled: false                       # Master enable flag; replaces Flannel when true
cilium_version: ""                          # REQUIRED when enabled — pin exact version, no "latest"
cilium_namespace: "kube-system"
cilium_helm_repo: "https://helm.cilium.io/"
cilium_helm_release_name: "cilium"
cilium_helm_values: {}                       # Additional Helm values merged with role defaults
cilium_egress_gateway_enabled: false         # Sets egressGateway.enabled in Helm values; auto-set true when kube_vip_egress_enabled: true
```

## Role Tasks

- Adds the Cilium Helm repository
- Auto-enables `egressGateway.enabled` in Helm values when `kube_vip_egress_enabled: true` (kube-vip role)
- Installs/upgrades the Cilium Helm release, pinned to `cilium_version`
- Waits for the Cilium DaemonSet to report all pods ready

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
