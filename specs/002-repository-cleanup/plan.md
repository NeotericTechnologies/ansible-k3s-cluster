# Implementation Plan: Repository Cleanup and Documentation Alignment

**Branch**: `002-before-specify` | **Date**: 2026-07-01 | **Spec**: [spec.md](specs/002-repository-cleanup/spec.md)

**Input**: Feature specification from `/specs/002-repository-cleanup/spec.md`

## Summary

Remove obsolete repository artifacts, eliminate undocumented hard-coded version usage by centralizing version sources, and align operational documentation with the actual repository state. The implementation approach is evidence-driven cleanup with reference tracing, staged removal criteria, and workflow validation gates so core k3s lifecycle behavior remains intact.

## Technical Context

**Language/Version**: Ansible YAML playbooks/roles plus Markdown documentation

**Primary Dependencies**: Ansible Core role/playbook structure, inventory/group_vars model, shell-based repository validation commands (`grep`, `ansible-playbook --syntax-check`, `ansible-lint`)

**Storage**: Git repository filesystem artifacts (playbooks, roles, inventories, docs, tests)

**Testing**: Reference tracing via search, syntax checks for documented entrypoints, smoke test selection for impacted workflows

**Target Platform**: Debian/Ubuntu-like Linux control hosts managing k3s clusters with Ansible

**Project Type**: Infrastructure-as-code repository maintenance and documentation governance

**Performance Goals**: Cleanup changes complete with zero regressions in documented lifecycle workflows and full removal of stale references for deleted artifacts

**Constraints**: Must preserve constitution requirements for k3s version pinning, role separation, secure defaults, and inventory-driven behavior; must avoid destructive cluster operations during validation

**Scale/Scope**: Repository-wide cleanup across `ansible/`, `docs/`, `tests/`, and feature specs for one active cleanup feature

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Cleanup explicitly removes non-essential or obsolete artifacts and preserves core lifecycle playbooks |
| II. Idempotent Cluster Provisioning | PASS | Validation strategy requires syntax/check-mode and smoke-test confirmation before/after cleanup changes |
| III. k3s-Specific Constraints | PASS | Version-centralization requirement reinforces pinned, configurable k3s/addon versions and avoids implicit upgrades |
| IV. Clear Inventory and Node Roles | PASS | Cleanup scope includes preserving inventory/group semantics and removing stale references that blur role boundaries |
| V. Security, Networking, and Upgrades | PASS | Documentation refresh requires explicit upgrade/version guidance and no secret material in repo |

### Post-Phase 1 Re-Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Data model and contracts constrain removals to unsupported artifacts only |
| II. Idempotent Cluster Provisioning | PASS | Quickstart validation includes check-mode/lint/smoke evidence gates |
| III. k3s-Specific Constraints | PASS | Contracts require centralized version sources and explicit k3s compatibility boundaries |
| IV. Clear Inventory and Node Roles | PASS | Design artifacts preserve inventory-driven operation and mandate reference-integrity checks |
| V. Security, Networking, and Upgrades | PASS | Design includes documentation and change-record requirements for version and upgrade impacts |

## Project Structure

### Documentation (this feature)

```text
specs/002-repository-cleanup/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cleanup-contracts.md
└── tasks.md
```

### Source Code (repository root)

```text
ansible/
├── playbooks/
├── roles/
├── inventories/
├── group_vars/
└── requirements.yml

docs/
├── ansible-k3s-baseline.md
├── ansible-structure.md
└── ai-prompts/

tests/
└── ansible/
    ├── inventories/
    └── smoke/

specs/
├── 001-k3s-ansible-baseline/
└── 002-repository-cleanup/
```

**Structure Decision**: Keep the existing Ansible-centered repository layout and implement cleanup through targeted changes to existing directories rather than introducing new runtime modules.

## Complexity Tracking

No constitution violations requiring justification.
