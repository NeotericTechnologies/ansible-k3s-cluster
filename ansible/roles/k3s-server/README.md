# k3s-server Role

## Purpose

Install and configure k3s control-plane (server) nodes with embedded etcd high availability support.

## Requirements

- k3s-common role must be applied first for prerequisite validation
- Target hosts in `k3s_servers` inventory group
- Odd number of control-plane nodes (1, 3, or 5) for HA mode

## Role Tasks

### Installation

- Detects if k3s is already installed and checks version
- Installs k3s via official installation script from https://get.k3s.io
- Configures first control-plane node with `--cluster-init` for embedded etcd
- Joins additional control-plane nodes to the first server
- Supports single-node mode without embedded etcd

### Configuration

- Applies control-plane VIP as TLS SAN for API server access
- Configures k3s with custom server arguments (disable traefik, servicelb by default)
- Sets up flannel VXLAN networking (default CNI)

### Kubeconfig

- Copies kubeconfig to user home directory
- Replaces localhost with control-plane VIP for external access

## Role Variables

### Required (from group_vars/all.yml)

```yaml
k3s_version: "v1.28.5+k3s1"
control_plane_vip: "192.168.1.100"
api_port: 6443
ha_mode: "embedded-etcd-ha"  # or "single-node"
```

### Optional (from group_vars/k3s_servers.yml)

```yaml
k3s_server_extra_args: >-
  --disable traefik
  --disable servicelb
  --flannel-backend=vxlan

k3s_server_labels: {}
k3s_server_taints: []
```

## Dependencies

- k3s-common role (must run first)

## Example Playbook

```yaml
- hosts: k3s_servers
  roles:
    - role: k3s-common
    - role: k3s-server
```

## Tags

- `install`: Run only installation tasks
- `k3s-server`: Run all k3s-server tasks
- `kubeconfig`: Run only kubeconfig configuration

## References

- [k3s Documentation](https://docs.k3s.io/)
- [Feature Specification FR-001](../../specs/001-k3s-ansible-baseline/spec.md)
