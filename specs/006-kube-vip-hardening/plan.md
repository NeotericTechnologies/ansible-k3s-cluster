# Implementation Plan: Kube-VIP Hardening

**Branch**: `006-kube-vip-hardening` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-kube-vip-hardening/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Enhance kube-vip operations for production-grade HA networking by implementing default-on managed egress with explicit opt-out, enabling resilient service leader election behavior under quorum loss, adding DHCP-driven LoadBalancer address lifecycle handling, and enforcing a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider. The implementation approach extends the existing `kube-vip` role and related lifecycle playbooks while preserving idempotent behavior and compatibility with both fresh deployments and upgrades.

## Technical Context

**Language/Version**: Ansible 2.15+ (YAML playbooks, Jinja2 templates), Kubernetes manifests

**Primary Dependencies**: k3s, kube-vip, kube-vip-cloud-provider, kubectl, Helm 3

**Storage**: N/A (configuration/state managed via Kubernetes API resources)

**Testing**: `ansible-playbook --check`, repository smoke scenarios in `tests/ansible/smoke/`, runtime validation via `kubectl` status checks

**Target Platform**: Debian/Ubuntu-like Linux nodes (systemd, x86_64/arm64) running k3s

**Project Type**: Infrastructure-as-code Ansible repository for k3s cluster lifecycle

**Performance Goals**: Automatic leader failover within 30 seconds for >=95% events; DHCP assignment within 60 seconds for >=95% of new services; no-op re-run remains idempotent

**Constraints**: Preserve existing lifecycle entrypoints; fail-safe behavior for invalid opt-out config (managed egress remains active); no default broad RBAC privileges; quorum-loss behavior must prevent unsafe leader churn

**Scale/Scope**: Single-node through small HA clusters (1-5 servers, 1-20 agents) with cluster-wide default managed egress and optional per-workload opt-out

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Changes are constrained to kube-vip-related role/playbook paths and documented contracts |
| II. Idempotent Cluster Provisioning | PASS | Design requires re-runnable RBAC reconciliation and deterministic fallback behavior |
| III. k3s-Specific Constraints | PASS | Feature is k3s-native and uses existing k3s cluster lifecycle semantics |
| IV. Clear Inventory and Node Roles | PASS | Behavior remains inventory-driven; no hard-coded host decisions introduced |
| V. Security, Networking, and Upgrades | PASS | Least-privilege RBAC baseline, explicit networking behavior, and upgrade-safe reconciliation are required |

**Post-Phase 1 Re-check**: PASS. Research and design artifacts preserve repository role boundaries, keep security defaults explicit, and avoid non-idempotent or destructive operations.

## Project Structure

### Documentation (this feature)

```text
specs/006-kube-vip-hardening/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── kube-vip-lifecycle-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── group_vars/
│   └── all.yml                               # global defaults and feature flags
├── playbooks/
│   ├── cluster-core.yml                      # lifecycle entrypoint
│   ├── cluster-addons.yml                    # lifecycle entrypoint
│   ├── upgrade-k3s.yml                       # lifecycle entrypoint
│   ├── includes/
│   │   └── upgrade-kube-vip.yml              # kube-vip orchestration include
│   └── site.yml                              # top-level orchestrator
└── roles/
    └── kube-vip/
        ├── defaults/main.yml                 # kube-vip configurable variables
        ├── tasks/install.yml                 # install/upgrade/reconcile flow
        └── templates/                        # manifests (daemonsets, RBAC, config)

tests/
└── ansible/
    └── smoke/                                # executable validation scenarios

docs/
├── ansible-k3s-baseline.md                   # operator-facing behavior docs
└── ai-prompts/kube-vip-configuration.md      # feature input context
```

**Structure Decision**: Reuse the existing ansible lifecycle architecture and keep all implementation changes inside kube-vip role/playbook paths plus shared group variables. No new top-level project structure is introduced.

## Complexity Tracking

No constitution violations requiring justification.
