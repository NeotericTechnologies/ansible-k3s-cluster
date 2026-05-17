# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-17 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks and roles for the complete lifecycle of a k3s cluster: provisioning with embedded etcd HA, node management, minor/patch upgrades, and optional platform add-ons (cert-manager with pluggable DNS-01 providers, multus VLAN networking, Rancher, rancher-monitoring, Traefik, kube-vip as DaemonSet, and optional Synology CSI). All deployments must be k3s-compatible without using symlinks, copying files to nodes, or modifying default k3s paths.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s, kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI driver, Helm (for chart-based add-ons)

**Storage**: Embedded etcd (k3s HA datastore); optional Synology CSI for persistent volumes

**Testing**: ansible-lint, `ansible-playbook --check`, smoke tests via test inventories

**Target Platform**: systemd-based Debian/Ubuntu-family Linux on x86_64 and arm64

**Project Type**: Infrastructure-as-Code (Ansible playbooks/roles)

**Performance Goals**: Provision reference topology (3 control-plane + 3 worker) within 60 minutes under normal network conditions

**Constraints**:
- All deployments must be k3s-compatible (no symlinks on nodes, no file copies to nodes, no modification of default k3s paths)
- kube-vip must be deployed as DaemonSet (not static pod)
- No secrets in repository; Ansible Vault or external secret management required
- Idempotent and safe to re-run without data loss

**Scale/Scope**: 1–3 control-plane nodes, up to ~10 worker nodes (small-to-medium clusters)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core cluster separate from add-ons; add-ons in dedicated roles/playbook |
| II. Idempotent Cluster Provisioning | PASS | All tasks designed for convergence; re-run safe |
| III. k3s-Specific Constraints (NON-NEGOTIABLE) | PASS | k3s version pinned, roles respect k3s flags, no kubeadm assumptions, no symlinks/file copies/path changes on nodes |
| IV. Clear Inventory and Node Roles | PASS | `k3s_servers` and `k3s_agents` groups; behavior derived from inventory/vars |
| V. Security, Networking, and Upgrades | PASS | No default credentials, TLS by k3s, networking explicit and configurable, upgrades controlled |

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
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml              # Galaxy/collection dependencies
├── group_vars/
│   ├── all.yml                   # Cluster-wide defaults
│   ├── k3s_servers.yml           # Server-specific vars
│   └── k3s_agents.yml            # Agent-specific vars
├── host_vars/                    # Per-host overrides
├── inventories/
│   ├── examples/
│   │   ├── ha-cluster/hosts.ini
│   │   └── single-node/hosts.ini
│   ├── production/
│   └── test-cluster/
├── playbooks/
│   ├── cluster-core.yml          # Core k3s provisioning
│   ├── cluster-addons.yml        # Platform add-ons
│   ├── scale-nodes.yml           # Node add/remove
│   └── upgrade-k3s.yml           # Minor/patch upgrades
└── roles/
    ├── k3s-common/               # Shared prerequisites/dependencies
    ├── k3s-server/               # Control-plane installation
    ├── k3s-agent/                # Worker installation
    ├── kube-vip/                 # VIP/LB (DaemonSet mode)
    ├── cert-manager/             # cert-manager + DNS-01 issuers
    ├── multus/                   # VLAN networking
    ├── rancher/                  # Rancher management console
    ├── rancher-monitoring/       # Observability stack
    ├── traefik/                  # Ingress controller
    └── synology-csi/             # Optional Synology storage

tests/
└── ansible/
    ├── inventories/local         # Local test inventory
    └── smoke/                    # Smoke test playbooks
```

**Structure Decision**: Ansible-native layout with playbooks as entrypoints, roles for component isolation, and inventories for environment separation. Tests use dedicated smoke playbooks against test inventories.

## Complexity Tracking

No constitution violations requiring justification.
