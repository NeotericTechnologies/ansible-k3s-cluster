# Tasks: Repository Cleanup and Documentation Alignment

**Input**: Design documents from /specs/002-repository-cleanup/

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/cleanup-contracts.md, quickstart.md

**Tests**: No separate test-authoring tasks are included because the specification does not require TDD or new automated test suites; validation tasks execute existing syntax/lint/smoke checks.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: [ID] [P?] [Story] Description

- [P] indicates a task that can run in parallel with other [P] tasks in the same phase.
- [Story] labels are used only in user story phases.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare cleanup tracking and baseline audit artifacts.

- [ ] T001 Create cleanup working notes in specs/002-repository-cleanup/implementation-notes.md
- [ ] T002 Create cleanup decision log template in docs/cleanup-decision-record.md
- [ ] T003 [P] Capture baseline artifact reference scan commands in specs/002-repository-cleanup/implementation-notes.md
- [ ] T004 [P] Capture baseline workflow validation command matrix in specs/002-repository-cleanup/implementation-notes.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared analysis outputs required by all user stories.

**CRITICAL**: No user story implementation begins until this phase is complete.

- [ ] T005 Build repository artifact inventory table in specs/002-repository-cleanup/implementation-notes.md
- [ ] T006 [P] Build workflow-to-artifact dependency map in specs/002-repository-cleanup/implementation-notes.md
- [ ] T007 [P] Build documentation topic index with validation status in specs/002-repository-cleanup/implementation-notes.md
- [ ] T008 Build version source catalog from ansible/group_vars/all.yml in specs/002-repository-cleanup/implementation-notes.md
- [ ] T009 [P] Build role/playbook version consumer list from ansible/roles and ansible/playbooks in specs/002-repository-cleanup/implementation-notes.md
- [ ] T010 Define removal safety criteria checklist in specs/002-repository-cleanup/implementation-notes.md

**Checkpoint**: Foundational inventory, dependency mapping, and validation criteria are ready.

---

## Phase 3: User Story 1 - Remove Obsolete Repository Content (Priority: P1) MVP

**Goal**: Remove unsupported or unused artifacts without breaking supported workflows.

**Independent Test**: Candidate removals can be validated by reference scans and syntax/smoke checks with zero unresolved dependencies.

### Implementation for User Story 1

- [ ] T011 [US1] Identify obsolete candidate artifacts and rationale in specs/002-repository-cleanup/implementation-notes.md
- [ ] T012 [P] [US1] Verify candidate references across ansible/ docs/ tests/ using commands documented in specs/002-repository-cleanup/quickstart.md
- [ ] T013 [US1] Update docs/cleanup-decision-record.md with remove/update/retain decisions for all candidates
- [ ] T014 [US1] Remove confirmed obsolete smoke artifact tests/ansible/smoke/dns-provider-switch-test.yml
- [ ] T015 [US1] Remove or update references to removed artifact in tests/ansible/smoke/smoke.yml
- [ ] T016 [P] [US1] Remove or update references to removed artifact in docs/ansible-k3s-baseline.md
- [ ] T017 [P] [US1] Remove or update references to removed artifact in docs/ansible-structure.md
- [ ] T018 [P] [US1] Remove or update references to removed artifact in README.md
- [ ] T019 [US1] Validate no stale references to removed artifacts and record evidence in docs/cleanup-decision-record.md
- [ ] T020 [US1] Run lifecycle playbook syntax checks and record outcomes in docs/cleanup-decision-record.md

**Checkpoint**: Obsolete artifacts are removed safely and all supported workflows remain valid.

---

## Phase 4: User Story 2 - Standardize Version Configuration (Priority: P2)

**Goal**: Eliminate undocumented hard-coded versions and ensure centralized version control points.

**Independent Test**: Maintainer can update designated version source locations and find no hidden version edits required.

### Implementation for User Story 2

- [ ] T021 [US2] Document canonical version-source policy in docs/ansible-structure.md
- [ ] T022 [P] [US2] Inventory hard-coded version literals in ansible/playbooks and record findings in specs/002-repository-cleanup/implementation-notes.md
- [ ] T023 [P] [US2] Inventory hard-coded version literals in ansible/roles and record findings in specs/002-repository-cleanup/implementation-notes.md
- [ ] T024 [US2] Normalize duplicated or conflicting version defaults between ansible/group_vars/all.yml and ansible/roles/*/defaults/main.yml
- [ ] T025 [US2] Replace hard-coded version references in ansible/playbooks/cluster-addons.yml with variable-driven values
- [ ] T026 [P] [US2] Replace hard-coded version references in ansible/roles/cert-manager/defaults/main.yml with centralized variable usage
- [ ] T027 [P] [US2] Replace hard-coded version references in ansible/roles/kube-vip/defaults/main.yml with centralized variable usage
- [ ] T028 [P] [US2] Replace hard-coded version references in ansible/roles/rancher/defaults/main.yml with centralized variable usage
- [ ] T029 [US2] Add version update guidance and override examples in README.md
- [ ] T030 [US2] Validate centralized version behavior and record evidence in docs/cleanup-decision-record.md

**Checkpoint**: Version configuration is centralized, documented, and maintainable.

---

## Phase 5: User Story 3 - Improve Documentation Clarity and Accuracy (Priority: P3)

**Goal**: Ensure contributor-facing docs reflect actual repository structure and workflows.

**Independent Test**: A contributor can follow documented setup/lifecycle guidance without encountering stale paths or ambiguous instructions.

### Implementation for User Story 3

- [ ] T031 [US3] Align repository overview and workflow entrypoints in README.md with current playbooks and roles
- [ ] T032 [P] [US3] Align lifecycle procedures in docs/ansible-k3s-baseline.md with current supported workflows
- [ ] T033 [P] [US3] Align structure and conventions in docs/ansible-structure.md with current repository layout
- [ ] T034 [P] [US3] Review role documentation references and fix stale links in ansible/roles/cert-manager/README.md
- [ ] T035 [P] [US3] Review role documentation references and fix stale links in ansible/roles/k3s-common/README.md
- [ ] T036 [P] [US3] Review role documentation references and fix stale links in ansible/roles/k3s-server/README.md
- [ ] T037 [P] [US3] Review role documentation references and fix stale links in ansible/roles/k3s-agent/README.md
- [ ] T038 [US3] Update contributor maintenance guidance in CONTRIBUTING.md for cleanup and version-centralization rules
- [ ] T039 [US3] Execute documentation reference integrity scan and record outcomes in docs/cleanup-decision-record.md
- [ ] T040 [US3] Execute quickstart validation commands from specs/002-repository-cleanup/quickstart.md and record outcomes in docs/cleanup-decision-record.md

**Checkpoint**: Documentation is accurate, navigable, and validated against current repository state.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency, quality checks, and readiness evidence.

- [ ] T041 [P] Run ansible-lint and capture results in docs/cleanup-decision-record.md
- [ ] T042 [P] Re-run full reference scan for removed/deprecated artifacts and capture results in docs/cleanup-decision-record.md
- [ ] T043 Ensure docs/cleanup-decision-record.md includes final artifact mapping with rationale and evidence
- [ ] T044 Update specs/002-repository-cleanup/implementation-notes.md with final completion summary and open follow-ups

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1): No dependencies.
- Foundational (Phase 2): Depends on Phase 1 completion; blocks all user stories.
- User Story phases (Phase 3-5): Depend on Phase 2 completion.
- Polish (Phase 6): Depends on completion of selected user stories.

### User Story Dependencies

- US1 (P1): Starts immediately after Phase 2 and defines the MVP.
- US2 (P2): Starts after Phase 2; can proceed after US1 checkpoint if conservative rollout is preferred.
- US3 (P3): Starts after Phase 2; should incorporate outcomes from US1 and US2 where docs are impacted.

### Within Each User Story

- Discovery/inventory tasks before implementation changes.
- File removals/normalizations before final validation tasks.
- Validation evidence must be recorded before story checkpoint is considered complete.

## Parallel Opportunities

- Phase 1: T003 and T004 can run in parallel.
- Phase 2: T006, T007, and T009 can run in parallel after T005 starts.
- US1: T016, T017, and T018 can run in parallel after T014.
- US2: T022 and T023 can run in parallel; T026, T027, and T028 can run in parallel after T024.
- US3: T032 through T037 can run in parallel by splitting docs/role README work.
- Polish: T041 and T042 can run in parallel.

## Parallel Example: User Story 2

- Parallel set A:
  - T022 Inventory hard-coded versions in ansible/playbooks
  - T023 Inventory hard-coded versions in ansible/roles
- Parallel set B:
  - T026 Normalize cert-manager defaults
  - T027 Normalize kube-vip defaults
  - T028 Normalize rancher defaults

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1.
2. Complete Phase 2.
3. Complete Phase 3 (US1).
4. Validate US1 independently via T019 and T020.
5. Stop for review before broader refactors.

### Incremental Delivery

1. Setup + Foundational.
2. Deliver US1 (safe obsolete cleanup).
3. Deliver US2 (version centralization).
4. Deliver US3 (documentation alignment).
5. Finish with Phase 6 cross-cutting validation.

### Parallel Team Strategy

1. Team aligns on Phase 1-2 shared outputs.
2. After Phase 2:
   - Engineer A owns US1 file cleanup/removals.
   - Engineer B owns US2 version normalization.
   - Engineer C owns US3 documentation alignment.
3. Merge at story checkpoints with documented evidence in docs/cleanup-decision-record.md.

## Notes

- All tasks follow the required checklist format: checkbox, task ID, optional [P], optional [US#], and explicit file path.
- User story tasks are independently testable using the validation steps embedded in each story phase.
