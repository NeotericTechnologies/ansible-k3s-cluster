# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-18 | **Spec**: [spec.md](specs/001-k3s-ansible-baseline/spec.md)

**Input**: Feature specification from `/specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks managing the complete lifecycle of a k3s cluster: deployment with embedded etcd HA, node management (add/remove), controlled minor/patch upgrades, and optional platform add-ons (cert-manager with pluggable DNS-01 challenges, Multus VLAN networking via official Helm chart, Rancher, rancher-monitoring, Traefik, Synology CSI, kube-vip as DaemonSet for control-plane VIP and service load balancing). All add-on deployments enforce k3s compatibility constraints (no symlinks, no file copies to nodes, no modification of default k3s paths).

## Technical Context

**Language/Version**: Ansible Core 2.15+, YAML playbooks and Jinja2 templates

**Primary Dependencies**: k3s (pinned version), kube-vip, cert-manager, Multus (official Helm chart), Rancher, rancher-monitoring, Traefik, Synology CSI driver, kubernetes.core Ansible collection

**Storage**: Embedded etcd (HA), optional Synology CSI for persistent volumes

**Testing**: ansible-lint, ansible-playbook --check, smoke tests (see tests/ansible/smoke/)

**Target Platform**: systemd-based Debian/Ubuntu-family Linux on x86_64 and arm64

**Project Type**: Infrastructure-as-Code / Ansible playbook collection

**Performance Goals**: Correctness, idempotence, and safe upgrades for small-to-medium on-prem clusters (1-3 control-plane, up to ~10 workers)

**Constraints**: No symlinks on nodes, no runtime file copies to nodes for add-ons, no modification of default k3s paths, k3s version pinned (no "latest")

**Scale/Scope**: Small-to-medium clusters (1-3 servers, 1-10 agents)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core provisioning separated from add-ons playbook |
| II. Idempotent Cluster Provisioning | PASS | All tasks designed for safe re-run; Helm and kubernetes.core modules ensure convergence |
| III. k3s-Specific Constraints | PASS | Version pinned, k3s paths respected, DaemonSet deployments (no static pods/file copies), Multus Helm values override paths for k3s |
| IV. Clear Inventory and Node Roles | PASS | k3s_servers/k3s_agents groups, host vars for labels/taints |
| V. Security, Networking, and Upgrades | PASS | No secrets in repo, explicit networking config, controlled upgrades via version variable |
| Development Workflow & Quality Gates | PASS | ansible-lint, --check mode, example inventories |

**Post-Phase 1 Re-check**: All design artifacts maintain compliance. Multus Helm chart installation via values-driven path configuration satisfies k3s compatibility without filesystem manipulation.

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-ansible-baseline/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── lifecycle-contracts.md
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml              # Ansible Galaxy dependencies
├── group_vars/
│   ├── all.yml                   # Cluster-wide defaults
│   ├── k3s_servers.yml           # Server-specific vars
│   └── k3s_agents.yml            # Agent-specific vars
├── host_vars/                    # Per-host overrides
├── inventories/
│   ├── examples/
│   │   ├── single-node/hosts.ini
│   │   └── ha-cluster/hosts.ini
│   ├── production/
│   └── test-cluster/
├── playbooks/
│   ├── cluster-core.yml          # Core k3s provisioning
│   ├── cluster-addons.yml        # Platform add-ons
│   ├── scale-nodes.yml           # Node add/remove
│   └── upgrade-k3s.yml           # Minor/patch upgrades
└── roles/
    ├── k3s-common/               # Shared prereqs and dependencies
    ├── k3s-server/               # Control-plane installation
    ├── k3s-agent/                # Worker installation
    ├── kube-vip/                 # VIP/LB (DaemonSet)
    ├── cert-manager/             # TLS with DNS-01 challenges
    ├── multus/                   # VLAN networking (Helm chart, DaemonSet)
    ├── traefik/                  # Ingress controller
    ├── rancher/                  # Management console
    ├── rancher-monitoring/       # Observability stack
    └── synology-csi/             # Optional storage

tests/
└── ansible/
    ├── inventories/local
    └── smoke/                    # Smoke test playbooks

docs/
├── ansible-k3s-baseline.md
└── ansible-structure.md
```

**Structure Decision**: Ansible role-per-component layout with separate playbooks for lifecycle operations (provision, add-ons, scale, upgrade). All add-ons deployed as in-cluster resources via Helm/kubernetes.core modules.

## Complexity Tracking

No constitution violations detected. All design choices align with stated principles.
