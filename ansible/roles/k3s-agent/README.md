# k3s-agent Role

## Purpose

Install and configure k3s worker (agent) nodes that join an existing k3s cluster.

## Requirements

- k3s-common role must be applied first for prerequisite validation
- k3s-server role must be applied to control-plane nodes first
- Cluster must be operational and control-plane VIP accessible
- Target hosts in `k3s_agents` inventory group

## Role Tasks

### Installation

- Detects if k3s-agent is already installed and checks version
- Fetches node token from first control-plane node
- Installs k3s-agent via official installation script from https://get.k3s.io
- Joins worker node to cluster via control-plane VIP URL

### Configuration

- Applies custom agent arguments (labels, taints, extra flags)
- Connects to cluster via `k3s_server_url` (control-plane VIP)

## Role Variables

### Required (from group_vars/all.yml)

```yaml
k3s_version: "v1.28.5+k3s1"
control_plane_vip: "192.168.1.100"
api_port: 6443
```

### Required (from group_vars/k3s_agents.yml)

```yaml
k3s_server_url: "https://{{ control_plane_vip }}:{{ api_port }}"
```

### Optional (from group_vars/k3s_agents.yml)

```yaml
k3s_agent_extra_args: ""
k3s_agent_labels: {}
k3s_agent_taints: []
```

## Dependencies

- k3s-common role (must run first)
- k3s-server role (must be completed on control-plane nodes)

## Example Playbook

```yaml
- hosts: k3s_agents
  roles:
    - role: k3s-common
    - role: k3s-agent
```

## Tags

- `install`: Run only installation tasks
- `k3s-agent`: Run all k3s-agent tasks

## References

- [k3s Documentation](https://docs.k3s.io/)
- [Feature Specification FR-001](../../specs/001-k3s-ansible-baseline/spec.md)
