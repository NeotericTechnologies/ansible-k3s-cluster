# k3s-common Role

## Purpose

Common prerequisites and validation tasks for all k3s nodes (both control-plane and workers).

## Requirements

- Target host running Debian or Ubuntu Linux
- systemd-based system
- x86_64 or arm64 architecture
- SSH access with sudo privileges

## Role Tasks

### Prerequisites Validation (FR-013)

Validates host prerequisites before k3s installation:

- Operating system family and distribution (Debian/Ubuntu only)
- System architecture (x86_64, arm64)
- systemd availability
- Minimum CPU cores (1 for workers, 2 for control-plane)
- Minimum memory (1GB for workers, 2GB for control-plane)
- Minimum disk space (20GB on root partition)
- Python 3 installation
- iptables or nftables availability
- Network connectivity to k3s GitHub releases (optional check)

### Dependencies Installation

Installs required packages:

- curl
- ca-certificates
- apt-transport-https
- software-properties-common
- iptables
- python3 and python3-pip

## Role Variables

### Defaults

```yaml
# Host prerequisite thresholds
k3s_min_cpu_cores: 1
k3s_min_memory_mb: 1024
k3s_min_disk_gb: 20

# Control-plane specific thresholds
k3s_server_min_cpu_cores: 2
k3s_server_min_memory_mb: 2048

# Network connectivity check
k3s_check_internet: true

# One-time host bootstrap actions
k3s_initial_server_setup: false
k3s_renew_dhcp_lease_on_bootstrap: true
k3s_initial_setup_marker_path: /var/lib/ansible-k3s/.initial-setup-complete
```

Set `k3s_initial_server_setup: true` for your first bootstrap run to apply hostname and DHCP lease renewal once per host.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: k3s_cluster
  roles:
    - role: k3s-common
      tags: prerequisites
```

## Tags

- `prerequisites`: Run only prerequisite validation
- `validation`: Alias for prerequisites
- `dependencies`: Run only dependency installation

## References

- [Feature Specification FR-013](../../specs/001-k3s-ansible-baseline/spec.md)
- [Ansible Structure Documentation](../../docs/ansible-structure.md)
