# ansible-k3s-cluster Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-16

## Active Technologies
- YAML-based Ansible playbooks and roles (Ansible Core 2.15+) + `ansible-core`, `ansible-lint`, k3s binaries, Helm charts for Rancher/rancher-monitoring, Kubernetes manifests/templates for cert-manager, multus, Traefik, kube-vip, Synology CSI (001-k3s-ansible-baseline)
- Embedded etcd for HA control-plane (default); optional Synology CSI-backed persistent storage (001-k3s-ansible-baseline)
- Ansible Core 2.15+ (YAML playbooks, Jinja2 templates) + k3s (pinned version), kube-vip (DaemonSet mode), Helm (for Rancher, rancher-monitoring, Traefik, cert-manager charts), Ansible collections (`kubernetes.core`, `community.kubernetes`) (001-k3s-ansible-baseline)
- Optional Synology CSI for persistent volumes; embedded etcd for HA state (001-k3s-ansible-baseline)

- Ansible playbooks (YAML); minimum supported Ansible Core version 2.15+ + Ansible, k3s, k3s-io/k3s-ansible collection, cert-manager, multus CNI, Rancher and rancher-monitoring stack, Traefik ingress, kube-vip (or equivalent LB/VIP mechanism), optional Synology CSI driver (001-k3s-ansible-baseline)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Ansible playbooks (YAML); minimum supported Ansible Core version 2.15+

## Code Style

Ansible playbooks (YAML); minimum supported Ansible Core version 2.15+: Follow standard conventions

## Recent Changes
- 001-k3s-ansible-baseline: Added Ansible Core 2.15+ (YAML playbooks, Jinja2 templates) + k3s (pinned version), kube-vip (DaemonSet mode), Helm (for Rancher, rancher-monitoring, Traefik, cert-manager charts), Ansible collections (`kubernetes.core`, `community.kubernetes`)
- 001-k3s-ansible-baseline: Added YAML-based Ansible playbooks and roles (Ansible Core 2.15+) + `ansible-core`, `ansible-lint`, k3s binaries, Helm charts for Rancher/rancher-monitoring, Kubernetes manifests/templates for cert-manager, multus, Traefik, kube-vip, Synology CSI

- 001-k3s-ansible-baseline: Added Ansible playbooks (YAML); minimum supported Ansible Core version 2.15+ + Ansible, k3s, k3s-io/k3s-ansible collection, cert-manager, multus CNI, Rancher and rancher-monitoring stack, Traefik ingress, kube-vip (or equivalent LB/VIP mechanism), optional Synology CSI driver

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
