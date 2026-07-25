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

### Consolidated RBAC (FR-008, FR-009)

- Single ClusterRole `kube-vip` (`templates/kube-vip-rbac.yaml.j2`) grants the union of permissions
  required by both the kube-vip DaemonSet and the kube-vip-cloud-controller Deployment.
- Two ServiceAccounts (`kube-vip`, `kube-vip-cloud-controller`) and two ClusterRoleBindings, both
  referencing the single ClusterRole.
- Applied with `state: present` before the DaemonSet/Deployment on every run — clean overwrite,
  no custom-rule detection or migration. Any manually applied rules not in the template are
  overwritten on the next role run (by design).

### Service Load Balancer (FR-012)

- Deploys kube-vip cloud controller for LoadBalancer service type
- Creates ConfigMap with IP address pool for LoadBalancer IPs
- Enables LoadBalancer services (replaces k3s default servicelb/klipper-lb)
- Uses nftables for port forwarding (v1.1.2+)

### DHCP Mode for LoadBalancer IPs (FR-007, FR-010)

- `kube_vip_lb_dhcp_enabled: true` switches the LoadBalancer IP pool from the static
  `kube_vip_lb_ip_range` to per-service DHCP-assigned addresses.
- **Mutually exclusive with `kube_vip_lb_ip_range`** — setting both a non-empty
  `kube_vip_lb_ip_range` and `kube_vip_lb_dhcp_enabled: true` fails validation
  (`ansible/roles/kube-vip/tasks/validate.yml`).
- When enabled, the `kubevip` ConfigMap omits the `range-global` key entirely.
- **DHCP networking prerequisites**:
  - An external DHCP server reachable from the node network is required.
  - Nodes must support macvlan interfaces with a MAC address the DHCP server can lease
    against (kube-vip generates a macvlan interface per DHCP-assigned service).
  - The `macvlan` kernel module must be loaded on all control-plane nodes.
- **Operator action required per service**: set `loadBalancerIP: 0.0.0.0` on each Service
  of `type: LoadBalancer` to request a DHCP-assigned address instead of one drawn from a
  static pool.

### Service Leader Election (FR-004, FR-005)


- `kube_vip_svc_election_enabled: true` enables per-service leader election: each
  LoadBalancer Service holds its own `coordination.k8s.io` Lease, and kube-vip instances
  compete for it independently — spreads VIP ownership across nodes instead of pinning
  all services to one global leader.
- Automatically forced `true` when `kube_vip_egress_enabled: true` (required for egress VIP
  binding to the active gateway node).
- Lease timing is controlled via `vip_leaseduration` (default `15`s), `vip_renewdeadline`
  (default `10`s), and `vip_retryperiod` (default `2`s).

### Load-Balanced Egress Gateway (FR-001–FR-003a)

Combines a kube-vip HA LoadBalancer VIP with a Cilium `CiliumEgressGatewayPolicy` so all
outbound pod traffic exits through one stable, predictable IP. **Requires Cilium as the active
CNI** (`cilium_enabled: true`, see `ansible/roles/cilium`) — the playbook fails otherwise.

```yaml
kube_vip_egress_enabled: false                # Master enable flag
kube_vip_egress_ip: ""                        # REQUIRED when enabled — dedicated IP, independent of kube_vip_lb_ip_range
kube_vip_egress_hostname: ""                  # Documentation only — DNS registration is out of scope
kube_vip_egress_namespace: "kube-system"
kube_vip_egress_policy_name: "egress-gateway-policy"
kube_vip_egress_pod_selector: {}              # Label selector for gated pods — operators SHOULD restrict this
kube_vip_egress_namespace_selector: {}
kube_vip_egress_gateway_node_selector:
  node-role.kubernetes.io/control-plane: "true"
kube_vip_egress_gateway_interface: "{{ kube_vip_interface }}"
```

**`kube_vip_egress_gateway_node_selector` CONSTRAINT**: MUST only match nodes where the kube-vip
DaemonSet actually runs (the DaemonSet is hard-affinitized to
`node-role.kubernetes.io/control-plane`). Targeting worker-only nodes means the egress IP is
never bound and Cilium finds no active gateway — egress silently breaks. Select a subset of
control-plane nodes; use ≥2 nodes in HA clusters to avoid a single point of failure.

**Failover behavior**: kube-vip `svc_election` (auto-enabled) binds the egress VIP to the
current leader node within the pool selected by `kube_vip_egress_gateway_node_selector`. On
node failure, kube-vip migrates the VIP via ARP within `vip_leaseduration` (default 15s);
Cilium detects the new binding automatically and reroutes matching pod egress — no manual
coordination required.

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

# Test LoadBalancer service (if enabled)
kubectl create service loadbalancer test --tcp=80:80
kubectl get svc test  # Should show EXTERNAL-IP from pool
```

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
