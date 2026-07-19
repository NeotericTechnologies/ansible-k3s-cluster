# Implementation Plan: Kube-VIP Egress and HA Hardening

**Branch**: `006-kube-vip-hardening` | **Date**: 2026-07-18 | **Spec**: specs/006-kube-vip-hardening/spec.md

**Input**: Feature specification from `specs/006-kube-vip-hardening/spec.md`

## Summary

Extend the existing kube-vip role and cluster playbooks to add four coordinated behaviors: default-on kube-vip egress with explicit opt-out, service-election-backed LoadBalancer leadership, environment-wide DHCP mode for kube-vip LoadBalancer services, and hard-fail RBAC regression gates. Egress-enabled workload services are declared through `kube_vip_services` and applied automatically by the kube-vip role, removing manual Service deployment from the operational path. Keep the feature inside the existing Ansible automation surface and validate it with documented checks, smoke tests, and traceable evidence.

## Technical Context

**Language/Version**: Ansible YAML; current kube-vip images pinned to `v1.1.2` and `v0.0.12` cloud provider

**Primary Dependencies**: `ansible-core`, `kubectl`, `kube-vip`, `kube-vip-cloud-provider`, existing `k3s-common` / `k3s-server` / `k3s-agent` roles

**Storage**: N/A; configuration lives in Ansible vars, templates, and generated Kubernetes manifests

**Testing**: Ansible syntax/check runs, local test inventory execution, kube-vip smoke validation, RBAC authorization checks, and service/election/DHCP verification against a live or representative cluster

**Target Platform**: Linux hosts running k3s on bare metal or virtualized infrastructure

**Project Type**: Infrastructure automation / Ansible playbooks and roles

**Performance Goals**: Preserve current cluster bootstrap behavior; meet spec recovery thresholds for egress failover, service-election failover, and DHCP assignment

**Constraints**: Must remain idempotent, k3s-specific, secure by default, inventory-driven, and evidence-backed; DHCP behavior must be consistent when enabled; RBAC validation must hard-fail production rollout

**Scale/Scope**: Existing single-node and small HA k3s clusters managed by the repository; kube-vip remains the authoritative control-plane VIP and LoadBalancer path

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Aligns with k3s baseline principles (minimal scope, idempotence, k3s-specific constraints, inventory clarity, secure defaults).
- [x] Uses token-optimized execution rules: Caveman skill active, CLI commands routed via `rtk`, and source operations routed via `codebase-memory-mcp` where available.
- [x] Uses silent output discipline: no narration, no unsolicited explanation, no reasoning disclosure, and diff-only file changes.
- [x] Distinguishes confirmed facts from assumptions and records evidence source for all material claims.
- [x] Avoids unsupported claims; when repository evidence is insufficient, cites explicit external references.

## Project Structure

### Documentation (this feature)

```text
specs/006-kube-vip-hardening/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
ansible/
├── group_vars/
├── playbooks/
│   ├── cluster-core.yml
│   └── cluster-addons.yml
├── roles/
│   └── kube-vip/
│       ├── defaults/main.yml
│       ├── README.md
│       └── templates/
└── inventories/

tests/
└── ansible/
    └── smoke/
```

**Structure Decision**: Keep the feature inside the existing Ansible role and playbook layout. No new application layer, API layer, or external contract surface is required.

## Complexity Tracking

No constitution violations require justification.
