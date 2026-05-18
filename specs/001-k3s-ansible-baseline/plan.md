# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-18 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks managing the complete lifecycle of a k3s cluster: provisioning with embedded etcd HA, node scaling, configuration updates, and minor/patch upgrades. Platform add-ons (cert-manager with pluggable DNS-01 providers, multus VLAN networking via thick plugin DaemonSet, kube-vip as DaemonSet for control-plane VIP and service load balancing, Rancher, rancher-monitoring, Traefik, optional Synology CSI) are deployed as in-cluster resources via Helm and Kubernetes API modules. All deployments are k3s-compatible: no symlinks, no file copies to nodes, no modification of default k3s paths.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s, kubernetes.core collection, community.kubernetes collection, Helm charts (multus, cert-manager, Rancher, rancher-monitoring, Traefik, Synology CSI, kube-vip)

**Storage**: Optional Synology CSI for persistent volumes; embedded etcd for k3s HA datastore

**Testing**: ansible-lint, ansible-playbook --check, smoke tests (tests/ansible/smoke/)

**Target Platform**: systemd-based Debian/Ubuntu Linux on x86_64 and arm64

**Project Type**: Infrastructure-as-Code (Ansible playbook collection)

**Performance Goals**: End-to-end cluster provisioning within 60 minutes for 3 control-plane + 3 worker reference topology

**Constraints**: k3s-specific — no symlinks on nodes, no file copies for runtime workloads, no modification of default k3s paths; all add-ons deployed via Kubernetes API

**Scale/Scope**: 1–3 control-plane nodes, up to ~10 workers; small-to-medium on-prem clusters

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core cluster separate from add-ons; two playbook entrypoints |
| II. Idempotent Cluster Provisioning | PASS | All tasks use Ansible modules; Helm state:present for convergence |
| III. k3s-Specific Constraints (NON-NEGOTIABLE) | PASS | Version pinned; k3s paths respected; no symlinks/file copies; DaemonSet deployments |
| IV. Clear Inventory and Node Roles | PASS | `k3s_servers` / `k3s_agents` groups; behavior derived from inventory/vars |
| V. Security, Networking, and Upgrades | PASS | No secrets in repo; TLS via k3s defaults; upgrades via variable + re-run |

**Post-Phase 1 Re-check**: All design artifacts maintain compliance. Kube-vip deployed as DaemonSet (not static pod). Multus deployed via Helm chart with thick plugin image. No violations identified.

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
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml           # Ansible Galaxy dependencies
├── group_vars/
│   ├── all.yml                # Cluster-wide defaults
│   ├── k3s_servers.yml        # Control-plane group vars
│   └── k3s_agents.yml         # Worker group vars
├── host_vars/                 # Per-host overrides
├── inventories/
│   ├── examples/
│   │   ├── ha-cluster/hosts.ini
│   │   └── single-node/hosts.ini
│   ├── production/
│   └── test-cluster/
├── playbooks/
│   ├── cluster-core.yml       # Core k3s provisioning
│   ├── cluster-addons.yml     # Platform add-ons
│   ├── scale-nodes.yml        # Node add/remove
│   └── upgrade-k3s.yml        # Minor/patch upgrades
└── roles/
    ├── k3s-common/            # Host prerequisites
    ├── k3s-server/            # Control-plane install
    ├── k3s-agent/             # Worker install
    ├── kube-vip/              # VIP + service LB (DaemonSet)
    ├── cert-manager/          # TLS with DNS-01 challenges
    ├── multus/                # VLAN networking (Helm, thick plugin)
    ├── rancher/               # Management console
    ├── rancher-monitoring/    # Observability
    ├── traefik/               # Ingress controller
    └── synology-csi/          # Optional persistent storage

tests/
└── ansible/
    ├── inventories/local
    └── smoke/                 # Smoke test playbooks
```

**Structure Decision**: Ansible-native layout with roles per component, inventory-driven configuration, and separate playbook entrypoints for core cluster vs. add-ons. Tests reside under `tests/ansible/`.

## Complexity Tracking

No constitution violations requiring justification.
