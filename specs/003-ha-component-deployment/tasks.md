# Tasks: HA Component Deployment

**Input**: Design documents from `/specs/003-ha-component-deployment/`

**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Include validation and smoke tasks because the specification requires measurable topology behavior and resilience outcomes.

**Organization**: Tasks are grouped by user story so each story is independently implementable and testable.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish shared variable scaffolding and documentation anchors for HA policy work.

- [ ] T001 Create HA policy variable section adjacent to component version variables in ansible/group_vars/all.yml
- [ ] T002 [P] Mirror HA policy variable section for test inventory in ansible/inventories/test-cluster/group_vars/all.yml
- [ ] T003 [P] Add HA policy variable reference table in docs/ansible-k3s-baseline.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement topology detection, policy resolution, and hard-fail validation primitives used by all stories.

**⚠️ CRITICAL**: No user story implementation begins until this phase is complete.

- [ ] T004 Add inventory-driven topology classification (`is_ha` from `k3s_servers` count) pre-task block in ansible/playbooks/cluster-core.yml
- [ ] T005 [P] Add shared topology classification pre-task block in ansible/playbooks/cluster-addons.yml
- [ ] T006 [P] Add shared topology classification pre-task block in ansible/playbooks/scale-nodes.yml
- [ ] T007 [P] Add shared topology classification pre-task block in ansible/playbooks/upgrade-k3s.yml
- [ ] T008 Create reusable HA policy resolution tasks with override precedence in ansible/roles/k3s-common/tasks/resolve-ha-policy.yml
- [ ] T009 Wire reusable HA policy resolution include into lifecycle playbooks in ansible/playbooks/cluster-core.yml
- [ ] T010 [P] Wire reusable HA policy resolution include into lifecycle playbooks in ansible/playbooks/cluster-addons.yml
- [ ] T011 [P] Wire reusable HA policy resolution include into lifecycle playbooks in ansible/playbooks/scale-nodes.yml
- [ ] T012 [P] Wire reusable HA policy resolution include into lifecycle playbooks in ansible/playbooks/upgrade-k3s.yml
- [ ] T013 Implement hard-fail validation reporter for enabled components in ansible/roles/k3s-common/tasks/validate-ha-targets.yml
- [ ] T014 Attach hard-fail validation reporter to lifecycle completion stages in ansible/playbooks/cluster-core.yml
- [ ] T015 [P] Attach hard-fail validation reporter to lifecycle completion stages in ansible/playbooks/cluster-addons.yml
- [ ] T016 [P] Attach hard-fail validation reporter to lifecycle completion stages in ansible/playbooks/scale-nodes.yml
- [ ] T017 [P] Attach hard-fail validation reporter to lifecycle completion stages in ansible/playbooks/upgrade-k3s.yml

**Checkpoint**: Foundation ready - user story implementation can proceed.

---

## Phase 3: User Story 1 - Enforce HA Defaults For HA Clusters (Priority: P1) 🎯 MVP

**Goal**: Ensure all enabled in-scope components automatically converge to HA behavior when server count is three or more.

**Independent Test**: Run core and addon lifecycle on HA inventory and verify each enabled component meets component-specific HA minimum targets with no violations.

### Tests for User Story 1

- [ ] T018 [P] [US1] Add HA convergence smoke scenario for core and addons in tests/ansible/smoke/smoke.yml
- [ ] T019 [P] [US1] Add component-target verification assertions for HA inventory in tests/ansible/smoke/idempotence-test.yml

### Implementation for User Story 1

- [ ] T020 [P] [US1] Define component-specific HA minimum targets for core components near version variables in ansible/group_vars/all.yml
- [ ] T021 [US1] Define component-specific HA minimum targets for addon components near version variables in ansible/group_vars/all.yml
- [ ] T022 [US1] Enforce HA targets for k3s control-plane service and kube-vip in ansible/playbooks/cluster-core.yml
- [ ] T023 [US1] Enforce HA targets for cert-manager, multus, traefik, rancher, rancher-monitoring, and synology-csi in ansible/playbooks/cluster-addons.yml
- [ ] T024 [US1] Implement component-level post-run state collection for enabled components in ansible/roles/k3s-common/tasks/collect-ha-observations.yml
- [ ] T025 [US1] Integrate HA observation collection with hard-fail validator in ansible/roles/k3s-common/tasks/validate-ha-targets.yml
- [ ] T043 [US1] Encode executable critical-component subset variables for resilience checks in ansible/group_vars/all.yml and ansible/inventories/test-cluster/group_vars/all.yml
- [ ] T044 [US1] Add HA disruption resilience smoke playbook for the critical subset in tests/ansible/smoke/ha-disruption-test.yml
- [ ] T045 [US1] Implement SC-003 availability calculation and threshold assertions in tests/ansible/smoke/ha-disruption-test.yml
- [ ] T046 [US1] Add lifecycle task wiring to execute critical-subset resilience validation in ansible/playbooks/cluster-core.yml and ansible/playbooks/cluster-addons.yml

**Checkpoint**: User Story 1 is independently functional and testable as MVP.

---

## Phase 4: User Story 2 - Preserve Non-HA Behavior For Small Clusters (Priority: P2)

**Goal**: Keep existing resource-conscious defaults for non-HA topologies while allowing explicit overrides.

**Independent Test**: Run lifecycle playbooks on non-HA inventory and confirm no forced HA settings unless explicit override variables are set.

### Tests for User Story 2

- [ ] T026 [P] [US2] Add non-HA baseline preservation smoke scenario in tests/ansible/smoke/smoke.yml
- [ ] T027 [P] [US2] Add override precedence validation scenario in tests/ansible/smoke/scale-test.yml

### Implementation for User Story 2

- [ ] T028 [US2] Implement non-HA branch defaults and bypass logic in ansible/roles/k3s-common/tasks/resolve-ha-policy.yml
- [ ] T029 [US2] Implement operator override precedence handling in ansible/roles/k3s-common/tasks/resolve-ha-policy.yml
- [ ] T030 [US2] Ensure non-HA preservation during node scale operations in ansible/playbooks/scale-nodes.yml
- [ ] T031 [US2] Ensure non-HA preservation during upgrade operations in ansible/playbooks/upgrade-k3s.yml

**Checkpoint**: User Story 2 works independently without regression to US1 behavior.

---

## Phase 5: User Story 3 - Make HA Expectations Explicit (Priority: P3)

**Goal**: Document explicit HA expectations, critical subset, and validation workflow for maintainers.

**Independent Test**: A maintainer can map every managed component to topology trigger and expected HA target from documentation alone.

### Tests for User Story 3

- [ ] T032 [P] [US3] Add documentation traceability check list for all managed components in specs/003-ha-component-deployment/quickstart.md

### Implementation for User Story 3

- [ ] T033 [US3] Publish per-component HA expectation matrix and topology triggers in docs/ansible-k3s-baseline.md
- [ ] T034 [US3] Document critical-component subset validation procedure in docs/ansible-k3s-baseline.md
- [ ] T035 [US3] Document same-scope rule for version and HA target variables in docs/ansible-structure.md
- [ ] T036 [US3] Add maintainer update workflow for new components and HA target variables in docs/ansible-structure.md

**Checkpoint**: User Story 3 documentation is independently usable and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks across all stories.

- [ ] T037 [P] Run full HA and non-HA quickstart validation flow and record results in specs/003-ha-component-deployment/quickstart.md
- [ ] T038 [P] Run ansible-lint and address HA-policy-related lint findings in ansible/playbooks/cluster-core.yml
- [ ] T039 [P] Run ansible-lint and address HA-policy-related lint findings in ansible/playbooks/cluster-addons.yml
- [ ] T040 [P] Run ansible-lint and address HA-policy-related lint findings in ansible/playbooks/scale-nodes.yml
- [ ] T041 [P] Run ansible-lint and address HA-policy-related lint findings in ansible/playbooks/upgrade-k3s.yml
- [ ] T042 Finalize feature documentation cross-links for plan/research/contracts/tasks in specs/003-ha-component-deployment/plan.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **User Story Phases (Phase 3-5)**: Depend on Foundational completion.
- **Polish (Phase 6)**: Depends on completion of selected user stories.

### User Story Dependencies

- **US1 (P1)**: Starts after Phase 2; no dependency on other user stories.
- **US2 (P2)**: Starts after Phase 2; independently testable on non-HA inventory without requiring US1 completion.
- **US3 (P3)**: Starts after Phase 2; independent documentation story using resolved policy model.

### Dependency Graph

- Setup -> Foundational -> {US1, US2, US3} -> Polish
- US1 is the recommended MVP slice.

### Within Each User Story

- Test tasks execute before or alongside implementation tasks and must fail when behavior is absent.
- Policy variable tasks precede enforcement/validation tasks.
- Enforcement tasks precede story checkpoint validation.

---

## Parallel Execution Examples

### User Story 1

- Run T018 and T019 in parallel (different test files).
- Run T020 first, then T021 (same file and intentionally sequenced to reduce edit contention).

### User Story 2

- Run T026 and T027 in parallel.
- T030 and T031 can run in parallel after T028/T029 are complete.

### User Story 3

- T033 and T035 can run in parallel (different docs files).
- T034 and T036 can run in parallel after base matrix is drafted.

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1 and Phase 2.
2. Deliver Phase 3 (US1).
3. Validate HA convergence and hard-fail behavior.
4. Pause for demo/review.

### Incremental Delivery

1. Foundation complete.
2. Deliver US1 (HA behavior in HA clusters).
3. Deliver US2 (non-HA preservation and override precedence).
4. Deliver US3 (maintainer-facing explicit documentation).
5. Complete polish and quality gates.

### Parallel Team Strategy

1. Team completes Phase 1 and Phase 2 together.
2. Split after foundation:
   - Engineer A: US1
   - Engineer B: US2
   - Engineer C: US3
3. Rejoin for Phase 6 polish and lint/check-mode verification.

---

## Notes

- `[P]` indicates tasks expected to be parallelizable with minimal dependency overlap.
- Every task includes an explicit file path and checklist format for immediate LLM execution.
- Story labels are applied only to user-story phases, as required.
