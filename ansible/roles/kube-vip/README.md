# kube-vip Role

## Purpose

Deploy and configure kube-vip for:
1. Control-plane virtual IP (VIP) for high-availability API server access
2. LoadBalancer service type support for ingress and application services

## Version

This role supports **kube-vip v1.1.2** and compatible cloud-provider versions. See [Migration Notes](#migration-notes) for upgrading from v0.6.4.

## Requirements

- k3s cluster deployed with k3s-server role
- Control-plane VIP defined in group_vars
- Network interface configured on control-plane nodes
- Kernel with nftables support (v1.1.2+)

## Role Tasks

### Control-Plane VIP (FR-011)

- Creates static pod manifest for kube-vip on control-plane nodes
- Configures ARP-based VIP with leader election
- Binds VIP to specified network interface
- Provides highly available Kubernetes API access via VIP

### Service Load Balancer (FR-012)

- Deploys kube-vip cloud controller for LoadBalancer service type
- Creates ConfigMap with IP address pool for LoadBalancer IPs
- Enables LoadBalancer services (replaces k3s default servicelb/klipper-lb)
- Uses nftables for port forwarding (v1.1.2+)

## Role Variables

### Required (from group_vars/all.yml)

```yaml
control_plane_vip: "192.168.1.100"
api_port: 6443
kube_vip_enabled: true
kube_vip_interface: "eth0"
```

### Optional

```yaml
kube_vip_version: "v1.1.2"
kube_vip_cloud_provider_version: "v0.0.12"
kube_vip_lb_enable: true
kube_vip_lb_ip_range: "192.168.1.200-192.168.1.220"
```

## Dependencies

- k3s-server role (must be deployed first)

## Example Playbook

```yaml
- hosts: k3s_servers
  roles:
    - role: k3s-common
    - role: k3s-server
    - role: kube-vip
```

## Handlers

- `Restart k3s`: Restarts k3s service when manifest changes

## Tags

- `install`: Run installation tasks
- `kube-vip`: Run all kube-vip tasks

## Verification

```bash
# Check control-plane VIP reachability
curl -k https://<control_plane_vip>:6443/healthz

# Check kube-vip pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Verify playbook-managed LoadBalancer services from kube_vip_services
kubectl get svc -A | grep -E 'LoadBalancer|EXTERNAL-IP'
```

## Egress Services Configuration

Configure workload egress Services via `kube_vip_services` in `ansible/group_vars/all.yml` and re-run `ansible/playbooks/cluster-core.yml`. The role renders and applies these Service resources automatically; manual `kubectl create service` steps are not required.

When `kube_vip_egress_enable: true`, service election is enabled automatically in the rendered kube-vip DaemonSet (`svc_election=true`) even if `kube_vip_service_election_enable` is set to `false`. This enforces the kube-vip requirement that egress operation depends on service election.

## Migration Notes

### Upgrading from v0.6.4 to v1.1.2

This role has been updated to support kube-vip v1.1.2, which includes several breaking changes and improvements:

**Key Changes:**
- Environment variable names converted from lowercase to UPPERCASE (e.g., `vip_arp` → `VIP_ARP`)
- New `PACKET_INTERFACE` environment variable required for multi-interface systems
- Cloud-provider updated from v0.0.7 to v0.2.1
- nftables support for more efficient port forwarding
- Enhanced security context with SYS_TIME capability
- Added `priorityClassName: system-cluster-critical` to ensure pods survive eviction

**Migration Steps:**
1. Update `kube_vip_version` to `v1.1.2` in `group_vars/all.yml`
2. Ensure `kube_vip_interface` is correctly set (usually `eth0`)
3. Re-run the playbook to deploy updated manifests
4. Verify VIP is functional: `ping <control_plane_vip>`
5. Monitor logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip`

**Compatibility:**
- Tested with k3s v1.28+
- Requires kernel with nftables support
- No manual intervention needed for rolling updates

## References

- [kube-vip Documentation](https://kube-vip.io/)
- [kube-vip v1.1.2 Release Notes](https://github.com/kube-vip/kube-vip/releases/tag/v1.1.2)
- [Feature Specification FR-011, FR-012](../../../specs/001-k3s-ansible-baseline/spec.md)
