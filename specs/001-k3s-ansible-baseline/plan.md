# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-16 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks and roles that manage the complete lifecycle of a k3s cluster — deployment, configuration updates, node scaling, HA etcd, and platform add-ons (cert-manager with pluggable DNS-01 providers, multus VLAN networking, kube-vip as DaemonSet for control-plane VIP and service load-balancing, Traefik, Rancher, rancher-monitoring, and optional Synology CSI). All provisioning is driven by inventory and variables, is idempotent, and supports minor/patch k3s version upgrades.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s (pinned version), kube-vip (DaemonSet mode), Helm (for Rancher, rancher-monitoring, Traefik, cert-manager charts), Ansible collections (`kubernetes.core`, `community.kubernetes`)

**Storage**: Optional Synology CSI for persistent volumes; embedded etcd for HA state

**Testing**: `ansible-lint`, `ansible-playbook --check`, smoke/idempotence/scale/upgrade test playbooks in `tests/ansible/smoke/`

**Target Platform**: systemd-based Debian/Ubuntu-family Linux on x86_64 and arm64, reachable via SSH

**Project Type**: Infrastructure-as-code / Ansible playbook collection

**Performance Goals**: Provision reference topology (3 CP + 3 workers) within 60 minutes under normal conditions (SC-001)

**Constraints**: Small-to-medium clusters (1–3 CP, up to ~10 workers); no major-version k3s upgrades; no full DR

**Scale/Scope**: 1–3 control-plane nodes, up to ~10 worker nodes per cluster

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Evidence |
|------|--------|----------|
| Minimal, focused playbooks | PASS | Core cluster and add-ons are separate playbooks; add-ons are individually toggled via variables |
| Idempotent cluster provisioning | PASS | All roles use Ansible modules; re-run safety is a first-class requirement (FR-002, SC-002) |
| k3s-specific constraints (NON-NEGOTIABLE) | PASS | Version pinned via variable; embedded etcd for HA; server/agent roles from inventory groups; no kubeadm assumptions |
| Clear inventory and node roles | PASS | `k3s_servers` and `k3s_agents` groups; behavior derived from inventory + vars; example inventories for single-node and HA |
| Security, networking, upgrades | PASS | No secrets in repo (Vault/external); CIDRs/ports configurable; upgrades controlled via version variable; kube-vip DaemonSet for VIP |
| Linting and quality gates | PASS | `ansible-lint` mandatory; `--check` mode supported; example inventories kept runnable |

**Post-Phase 1 Re-check**: PASS — data-model aligns with constitution constraints; kube-vip modeled as DaemonSet per planning directive; no violations identified.

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
├── group_vars/
│   ├── all.yml                   # Cluster-wide defaults (ClusterConfig, NetworkConfig)
│   ├── k3s_agents.yml            # Agent-specific defaults
│   └── k3s_servers.yml           # Server-specific defaults
├── host_vars/                    # Per-host overrides (labels, taints, IPs)
├── inventories/
│   ├── examples/
│   │   ├── ha-cluster/hosts.ini  # 3 CP + workers reference
│   │   └── single-node/hosts.ini # Single-node reference
│   ├── production/               # Real deployment inventory
│   └── test-cluster/             # Test/CI inventory
├── playbooks/
│   ├── cluster-core.yml          # Core k3s provisioning + kube-vip
│   ├── cluster-addons.yml        # Platform add-ons (cert-manager, multus, Rancher, etc.)
│   ├── scale-nodes.yml           # Join/remove nodes
│   └── upgrade-k3s.yml           # Minor/patch version upgrades
└── roles/
    ├── k3s-common/               # Shared prerequisites and dependencies
    ├── k3s-server/               # Control-plane installation
    ├── k3s-agent/                # Worker node installation
    ├── kube-vip/                 # kube-vip DaemonSet for CP VIP + service LB
    ├── cert-manager/             # cert-manager + DNS-01 issuers
    ├── multus/                   # multus CNI + NetworkAttachmentDefinitions
    ├── traefik/                  # Traefik ingress controller
    ├── rancher/                  # Rancher management console
    ├── rancher-monitoring/       # rancher-monitoring (Prometheus/Grafana)
    └── synology-csi/            # Optional Synology CSI driver

tests/
└── ansible/
    ├── inventories/local         # Local test inventory
    └── smoke/
        ├── smoke.yml             # Basic cluster health
        ├── idempotence-test.yml  # Re-run safety
        ├── scale-test.yml        # Node join/remove
        └── upgrade-test.yml      # Version upgrade

docs/
├── ansible-k3s-baseline.md      # Architecture overview
└── ansible-structure.md          # Repo layout documentation
```

**Structure Decision**: Ansible collection layout with separate playbooks for core cluster vs. add-ons, one role per component, inventory-driven configuration. Matches existing repository structure.

## Complexity Tracking

No constitution violations requiring justification. All gates pass.
