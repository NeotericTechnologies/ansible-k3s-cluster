# Tasks: Unified Upgrade Workflow

**Input**: Design documents from `specs/005-unified-upgrade-workflow/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the includes directory structure and new variables needed by the orchestrator

- [ ] T001 Create playbook includes directory at ansible/playbooks/includes/
- [ ] T002 [P] Add `component_compatibility` variable structure to ansible/group_vars/all.yml
- [ ] T003 [P] Add `allow_downgrade`, `upgrade_drain_timeout`, `upgrade_node_ready_timeout`, `upgrade_pause_between_nodes` variables to ansible/group_vars/all.yml
- [ ] T004 [P] Add `upgrade_components` registry variable file at ansible/playbooks/includes/vars/upgrade-components.yml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Version detection and upgrade plan computation — MUST be complete before any user story plays can function

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Implement live version detection for k3s binary (`k3s --version` on all nodes) in ansible/playbooks/includes/detect-versions.yml
- [ ] T006 Implement live version detection for Helm-deployed components (`helm list`) in ansible/playbooks/includes/detect-versions.yml
- [ ] T007 Implement version comparison logic (compute action: install/upgrade/downgrade/none per component) in ansible/playbooks/includes/compute-plan.yml
- [ ] T008 Implement constraint validation (k3s vs rancher max/min) in ansible/playbooks/includes/compute-plan.yml
- [ ] T009 Implement downgrade detection and blocking in ansible/playbooks/includes/compute-plan.yml
- [ ] T010 Implement upgrade plan summary output (debug task printing plan before execution) in ansible/playbooks/includes/compute-plan.yml

**Checkpoint**: Foundation ready — version detection and plan computation functional

---

## Phase 3: User Story 1 - Single Command Deployment and Upgrade (Priority: P1) 🎯 MVP

**Goal**: A single `site.yml` playbook that handles both fresh install and upgrades, calling existing playbooks/roles based on computed plan

**Independent Test**: Run `site.yml` on fresh hosts → full install. Run again with updated versions → only changed components upgrade. Run with no changes → no-op.

### Implementation for User Story 1

- [ ] T011 [US1] Create the unified orchestrator playbook at ansible/playbooks/site.yml with pre-flight reachability check (any_errors_fatal: true)
- [ ] T012 [US1] Add include of detect-versions.yml and compute-plan.yml as first plays in ansible/playbooks/site.yml
- [ ] T013 [US1] Add conditional import of cluster-core.yml plays for fresh install path in ansible/playbooks/site.yml
- [ ] T014 [US1] Add conditional import of cluster-addons.yml plays for fresh install path in ansible/playbooks/site.yml
- [ ] T015 [US1] Add conditional include of upgrade-addon.yml for each Helm-based component (cert-manager, traefik, rancher-monitoring) in ansible/playbooks/site.yml
- [ ] T016 [US1] Implement the generic Helm-based add-on upgrade include at ansible/playbooks/includes/upgrade-addon.yml
- [ ] T017 [US1] Wire no-op path: when compute-plan determines no changes needed, print summary and skip all upgrade includes in ansible/playbooks/site.yml

**Checkpoint**: site.yml handles fresh install and selective upgrades for Helm-based add-ons

---

## Phase 4: User Story 2 - Dependency-Aware Upgrade Ordering (Priority: P1)

**Goal**: The orchestrator enforces Rancher-before-k3s ordering and fails fast on constraint violations

**Independent Test**: Set incompatible k3s version → playbook fails with constraint error. Set Rancher + k3s versions → Rancher upgrades first.

### Implementation for User Story 2

- [ ] T018 [US2] Add ordering logic to site.yml: Rancher upgrade include positioned before k3s upgrade include based on upgrade_priority in ansible/playbooks/site.yml
- [ ] T019 [US2] Implement Rancher-specific upgrade include (Helm upgrade with version from rancher_version) at ansible/playbooks/includes/upgrade-rancher.yml
- [ ] T020 [US2] Add fail-fast assertion in compute-plan.yml: fail playbook if constraint_violations is non-empty before any changes in ansible/playbooks/includes/compute-plan.yml
- [ ] T021 [US2] Add validation for k3s version vs currently deployed Rancher's k3s_max when only k3s is being upgraded (no Rancher upgrade) in ansible/playbooks/includes/compute-plan.yml

**Checkpoint**: Dependency ordering enforced; constraint violations rejected before changes

---

## Phase 5: User Story 3 - Selective Component Upgrades (Priority: P2)

**Goal**: Only components with version drift execute; all others are cleanly skipped

**Independent Test**: Change one component version only → verify only that component's tasks run (via --check or actual execution).

**Depends on**: Phase 3 (US1) — site.yml must exist with component includes

### Implementation for User Story 3

- [ ] T022 [P] [US3] Add `when: component_plan[item].action in ['install', 'upgrade']` conditions to each component include in ansible/playbooks/site.yml
- [ ] T023 [P] [US3] Ensure detect-versions.yml sets `component_plan` fact with per-component action for all registered components in ansible/playbooks/includes/detect-versions.yml
- [ ] T024 [US3] Add idempotency guard: skip entire upgrade flow when all components report action=none in ansible/playbooks/site.yml

**Checkpoint**: Only changed components execute; no-op run produces zero changes

---

## Phase 6: User Story 4 - Safe Rolling Upgrades for k3s Nodes (Priority: P2)

**Goal**: k3s upgrades proceed with cordon/drain/upgrade/uncordon on servers (serial:1) then agents (serial:1) with health checks

**Independent Test**: Upgrade k3s version on a multi-node cluster → servers upgrade one at a time, each with drain and health check; then agents.

### Implementation for User Story 4

- [ ] T025 [US4] Implement rolling k3s server upgrade play (serial:1) with cordon, drain, upgrade, wait-for-ready, uncordon in ansible/playbooks/includes/upgrade-k3s-rolling.yml
- [ ] T026 [US4] Implement rolling k3s agent upgrade play (serial:1) with cordon, drain, upgrade, wait-for-ready, uncordon in ansible/playbooks/includes/upgrade-k3s-rolling.yml
- [ ] T027 [US4] Add health check between nodes: validate cluster node count and all nodes Ready before proceeding to next node in ansible/playbooks/includes/upgrade-k3s-rolling.yml
- [ ] T028 [US4] Add any_errors_fatal:true to rolling upgrade plays to stop on first failure in ansible/playbooks/includes/upgrade-k3s-rolling.yml
- [ ] T029 [US4] Add pause between node upgrades (upgrade_pause_between_nodes variable) in ansible/playbooks/includes/upgrade-k3s-rolling.yml
- [ ] T030 [US4] Wire upgrade-k3s-rolling.yml include into site.yml with conditional (only when k3s action is upgrade) in ansible/playbooks/site.yml
- [ ] T031 [US4] Implement kube-vip manifest-based upgrade include (re-apply static pod manifest with new version) at ansible/playbooks/includes/upgrade-kube-vip.yml
- [ ] T032 [US4] Implement manifest_label version detection for non-Helm components (kube-vip, multus) in ansible/playbooks/includes/detect-versions.yml

**Checkpoint**: Rolling k3s upgrades maintain cluster availability with proper drain/uncordon cycle

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, deprecation notices, backward compatibility validation

- [ ] T033 [P] Add deprecation notice comment to ansible/playbooks/upgrade-k3s.yml header pointing to site.yml
- [ ] T034 [P] Update README.md with unified workflow documentation (single command for install/upgrade)
- [ ] T035 [P] Add smoke test scenario for site.yml no-op run in tests/ansible/smoke/
- [ ] T036 Validate backward compatibility: ensure cluster-core.yml and cluster-addons.yml still function independently (manual check / --check mode)

---

## Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2)
                                          → Phase 5 (US3) [after US1, parallel with US2/US4]
                                          → Phase 6 (US4) [parallel with US2]
Phase 3-6 complete → Phase 7 (Polish)
```

### Story Completion Order

1. **US1** (P1): Depends on Phase 1 + 2. Delivers MVP — single playbook for install/upgrade.
2. **US2** (P1): Depends on US1 (site.yml must exist). Adds ordering + constraint enforcement.
3. **US3** (P2): Depends on US1 (site.yml with component includes must exist). Adds selective execution.
4. **US4** (P2): Depends on Phase 2 (compute-plan). Can parallelize with US2.

### Parallel Execution Examples

**Within Phase 1**: T002, T003, T004 can all run in parallel (different files).

**After Phase 2**: US3 (T022-T024) and US4 (T025-T030) can be developed in parallel since they modify different files (site.yml conditions vs upgrade-k3s-rolling.yml).

**Phase 7**: T031, T032, T033 are all independent files and can parallelize.

## Implementation Strategy

**MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1) = functional unified playbook for both install and upgrade paths. This alone delivers SC-001.

**Incremental delivery**:
1. MVP (US1): Single command works for install + upgrade
2. +US2: Constraint validation and Rancher-first ordering
3. +US3: Selective upgrades (only changed components)
4. +US4: Safe rolling k3s upgrades with drain/uncordon
5. +Polish: Docs, deprecation, tests
