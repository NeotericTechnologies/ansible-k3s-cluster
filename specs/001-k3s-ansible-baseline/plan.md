# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-23 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks and roles managing the complete lifecycle of a k3s cluster: provisioning with embedded etcd HA, configuration updates, node scaling, and controlled upgrades. Platform add-ons include kube-vip (DaemonSet), cert-manager with pluggable DNS-01 challenges, multus (thick plugin DaemonSet), Rancher, rancher-monitoring, Traefik, and optional Synology CSI (iSCSI/NFS with snapshots over HTTPS:8443). All deployments are k3s-compatible with no symlinks, no file copies to nodes, and no modification of default k3s paths.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: `kubernetes.core` collection, `community.kubernetes` collection, Helm (via `kubernetes.core.helm`), k3s installer script

**Storage**: Optional Synology CSI (iSCSI + NFS storage classes, HTTPS port 8443, self-signed certificates); embedded etcd for cluster state

**Testing**: `ansible-lint`, `ansible-playbook --check`, smoke tests (see `tests/ansible/smoke/`)

**Target Platform**: systemd-based Debian/Ubuntu Linux on x86_64 and arm64, reachable via SSH

**Project Type**: Infrastructure-as-code / Ansible automation

**Performance Goals**: Correctness, idempotence, and safe upgrades for small-to-medium on-prem clusters (1–3 control-plane, up to ~10 workers)

**Constraints**: No symlinks on nodes, no file copies to nodes for runtime workloads, no modification of default k3s paths, no hard-coded DNS provider

**Scale/Scope**: 1–3 control-plane nodes, up to ~10 worker nodes; single-node and HA cluster variants

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core cluster and add-ons are separate playbooks; add-ons are optional and gated by variables |
| II. Idempotent Cluster Provisioning | PASS | All tasks use Ansible modules with `state: present`; no destructive operations without guards |
| III. k3s-Specific Constraints | PASS | k3s version pinned, no symlinks/file copies/path modifications, k3s flags respected, DaemonSet-only deployments for kube-vip and multus |
| IV. Clear Inventory and Node Roles | PASS | `k3s_servers` and `k3s_agents` groups; behavior driven by inventory/variables, not hard-coded values |
| V. Security, Networking, and Upgrades | PASS | No secrets in repo (Vault/external), TLS enabled by default, networking explicit and configurable, upgrades controlled via version variable |

**Gate Result**: PASS — no violations.

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
│   ├── all.yml                # Cluster-wide variables
│   ├── k3s_agents.yml         # Agent-specific variables
│   └── k3s_servers.yml        # Server-specific variables
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
    ├── k3s-common/            # Prerequisites and shared tasks
    ├── k3s-server/            # Control-plane installation
    ├── k3s-agent/             # Worker node installation
    ├── kube-vip/              # DaemonSet VIP/service LB
    ├── cert-manager/          # cert-manager + DNS-01 issuers
    ├── multus/                # Thick plugin DaemonSet + NADs
    ├── rancher/               # Rancher management console
    ├── rancher-monitoring/    # Monitoring stack
    ├── traefik/               # Ingress controller
    └── synology-csi/          # Optional Synology CSI (iSCSI/NFS)

tests/ansible/
├── inventories/local
└── smoke/                     # Smoke and integration tests
```

**Structure Decision**: Ansible standard layout with roles-per-component, variable-driven inventory, and separated core vs. add-on playbooks.

## Complexity Tracking

No constitution violations requiring justification.
