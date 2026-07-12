# ansible-k3s-cluster Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-16

## Active Technologies
- YAML-based Ansible playbooks and roles (Ansible Core 2.15+) + `ansible-core`, `ansible-lint`, k3s binaries, Helm charts for Rancher/rancher-monitoring, Kubernetes manifests/templates for cert-manager, multus, Traefik, kube-vip, Synology CSI (001-k3s-ansible-baseline)
- Embedded etcd for HA control-plane (default); optional Synology CSI-backed persistent storage (001-k3s-ansible-baseline)
- Ansible Core 2.15+ (YAML playbooks, Jinja2 templates) + k3s (pinned version), kube-vip (DaemonSet mode), Helm (for Rancher, rancher-monitoring, Traefik, cert-manager charts), Ansible collections (`kubernetes.core`, `community.kubernetes`) (001-k3s-ansible-baseline)
- Optional Synology CSI for persistent volumes; embedded etcd for HA state (001-k3s-ansible-baseline)
- Ansible YAML playbooks/roles plus Markdown documentation + Ansible Core role/playbook structure, inventory/group_vars model, shell-based repository validation commands (`rg`, `ansible-playbook --syntax-check`, `ansible-lint`) (002-repository-cleanup)
- Git repository filesystem artifacts (playbooks, roles, inventories, docs, tests) (002-repository-cleanup)
- Ansible Core 2.15+ (YAML playbooks and Jinja2 templates) + Ansible roles/playbooks under `ansible/playbooks` and `ansible/roles`, `kubernetes.core` modules, Helm-managed addons where already used (003-ha-component-deployment)
- Git repository configuration files (`ansible/group_vars`, inventory `group_vars`, role defaults) and Kubernetes cluster state for runtime validation (003-ha-component-deployment)
- Ansible (Python-based); `kubernetes.core` collection ≥2.4.0 (already in `ansible/requirements.yml`) + `kubernetes.core.k8s`, `kubernetes.core.k8s_info`, `ansible.builtin.uri` (for remote manifest fetch); all already present in the collection requirements (004-k8s-module-refactor)
- N/A — no persistent data model changes; cluster state managed via Kubernetes API (004-k8s-module-refactor)
- Ansible 2.15+ (YAML playbooks, Jinja2 templates), Kubernetes manifests + k3s, kube-vip, kube-vip-cloud-provider, kubectl, Helm 3 (006-kube-vip-hardening)
- N/A (configuration/state managed via Kubernetes API resources) (006-kube-vip-hardening)

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
- 006-kube-vip-hardening: Added Ansible 2.15+ (YAML playbooks, Jinja2 templates), Kubernetes manifests + k3s, kube-vip, kube-vip-cloud-provider, kubectl, Helm 3
- 004-k8s-module-refactor: Added Ansible (Python-based); `kubernetes.core` collection ≥2.4.0 (already in `ansible/requirements.yml`) + `kubernetes.core.k8s`, `kubernetes.core.k8s_info`, `ansible.builtin.uri` (for remote manifest fetch); all already present in the collection requirements
- 003-ha-component-deployment: Added Ansible Core 2.15+ (YAML playbooks and Jinja2 templates) + Ansible roles/playbooks under `ansible/playbooks` and `ansible/roles`, `kubernetes.core` modules, Helm-managed addons where already used


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
