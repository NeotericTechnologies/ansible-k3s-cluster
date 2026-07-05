# Implementation Plan: Unified Upgrade Workflow

**Branch**: `feature/005-unified-upgrade-workflow` | **Date**: 2026-07-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-unified-upgrade-workflow/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Unify the cluster deployment and upgrade workflows into a single top-level playbook (`site.yml`) that detects live component versions, computes an upgrade plan based on version drift and dependency constraints, and executes changes in the correct order (Rancher before k3s, rolling k3s upgrades with cordon/drain). The existing playbooks remain functional for operators who prefer granular control.

## Technical Context

**Language/Version**: Ansible 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s, Helm 3 (for add-on version detection), kubectl

**Storage**: N/A (stateless — queries live cluster at runtime)

**Testing**: `ansible-playbook --check` mode, smoke tests in `tests/ansible/smoke/`

**Target Platform**: Debian/Ubuntu-like, systemd-based Linux (x86_64/arm64)

**Project Type**: Infrastructure-as-code (Ansible playbook collection)

**Performance Goals**: No-op run completes in <2 minutes; constraint validation in <30 seconds

**Constraints**: Must maintain cluster availability during rolling upgrades; must not break existing playbook interfaces

**Scale/Scope**: 1-5 server nodes, 1-10 agent nodes; 7-10 managed components

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | site.yml orchestrates existing roles/plays; does not merge unrelated concerns |
| II. Idempotent Cluster Provisioning | PASS | Live state detection + version comparison ensures no-op when nothing changed |
| III. k3s-Specific Constraints | PASS | k3s version pinned, rolling upgrade respects k3s server/agent distinction, no kubeadm assumptions |
| IV. Clear Inventory and Node Roles | PASS | Behavior driven from inventory groups (k3s_servers, k3s_agents) and variables |
| V. Security, Networking, Upgrades | PASS | Upgrades controlled via variables, cordon/drain for safety, fail-fast on constraint violations |

**Post-Phase 1 Re-check**: All gates remain PASS. The design uses existing role structure, adds no new security surface, and introduces cordon/drain safety that was previously absent.

## Project Structure

### Documentation (this feature)

```text
specs/005-unified-upgrade-workflow/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── lifecycle-contracts.md  # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── playbooks/
│   ├── site.yml                    # NEW: unified orchestrator playbook
│   ├── cluster-core.yml            # EXISTING: preserved
│   ├── cluster-addons.yml          # EXISTING: preserved
│   ├── upgrade-k3s.yml             # EXISTING: deprecated but functional
│   ├── scale-nodes.yml             # EXISTING: unchanged
│   └── includes/                   # NEW: modular upgrade includes
│       ├── vars/
│       │   └── upgrade-components.yml  # Component registry
│       ├── detect-versions.yml     # Gather live component versions
│       ├── compute-plan.yml        # Compute upgrade plan and validate constraints
│       ├── upgrade-k3s-rolling.yml # Rolling k3s upgrade (servers then agents)
│       ├── upgrade-rancher.yml     # Rancher-specific Helm upgrade
│       ├── upgrade-kube-vip.yml    # kube-vip manifest-based upgrade
│       └── upgrade-addon.yml       # Generic Helm-based add-on upgrade
├── group_vars/
│   └── all.yml                     # MODIFIED: add component_compatibility variable
└── roles/                          # EXISTING: all roles preserved unchanged
    ├── k3s-common/
    ├── k3s-server/
    ├── k3s-agent/
    ├── kube-vip/
    ├── cert-manager/
    ├── traefik/
    ├── rancher/
    ├── rancher-monitoring/
    ├── multus/
    └── synology-csi/
```

**Structure Decision**: The unified playbook lives alongside existing playbooks. Modular includes under `playbooks/includes/` keep the orchestrator lean. No new roles are created — the includes delegate to existing roles.

## Complexity Tracking

No constitution violations to justify. The design stays within existing patterns.
