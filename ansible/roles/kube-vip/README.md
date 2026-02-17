# kube-vip Role

## Purpose

Deploy and configure kube-vip for:
1. Control-plane virtual IP (VIP) for high-availability API server access
2. LoadBalancer service type support for ingress and application services

## Requirements

- k3s cluster deployed with k3s-server role
- Control-plane VIP defined in group_vars
- Network interface configured on control-plane nodes

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
kube_vip_version: "v0.6.4"
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

## References

- [kube-vip Documentation](https://kube-vip.io/)
- [Feature Specification FR-011, FR-012](../../specs/001-k3s-ansible-baseline/spec.md)
