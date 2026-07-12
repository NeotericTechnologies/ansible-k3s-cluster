# Tasks: Kube-VIP Hardening

**Input**: Design documents from `/specs/006-kube-vip-hardening/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: No new automated test suite was explicitly requested in the specification. Validation tasks use existing Ansible check-mode and quickstart scenarios.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label (US1, US2, US3, US4)
- Every task includes an explicit file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare feature scaffolding and default variable surfaces used by all stories.

- [ ] T001 Add kube-vip hardening feature variable scaffolding in ansible/roles/kube-vip/defaults/main.yml
- [ ] T002 Add inventory-level defaults for hardening toggles in ansible/group_vars/all.yml
- [ ] T003 [P] Add feature overview section for kube-vip hardening in docs/ansible-k3s-baseline.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared orchestration and status plumbing required before user story work.

**CRITICAL**: No user story implementation starts until this phase is complete.

- [ ] T004 Create shared kube-vip config validation tasks in ansible/roles/kube-vip/tasks/validate-config.yml
- [ ] T005 Create shared kube-vip status reporting tasks in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T006 Refactor kube-vip role entry flow to include shared validation/reporting in ansible/roles/kube-vip/tasks/install.yml
- [ ] T007 [P] Add shared hardening runtime config template in ansible/roles/kube-vip/templates/kube-vip-hardening-configmap.yaml.j2
- [ ] T008 Wire kube-vip hardening reconciliation path into unified upgrades in ansible/playbooks/includes/upgrade-kube-vip.yml

**Checkpoint**: Foundation complete. User stories can now proceed.

---

## Phase 3: User Story 1 - Stable Cluster Egress Identity (Priority: P1) MVP

**Goal**: Deliver default-on managed egress with explicit opt-out and fail-safe handling for invalid opt-out config.

**Independent Test**: Apply ansible/playbooks/site.yml and verify default managed egress, valid opt-out behavior, and invalid opt-out warning/fail-safe behavior.

- [ ] T009 [US1] Add managed egress default-on variable definitions in ansible/roles/kube-vip/defaults/main.yml
- [ ] T010 [P] [US1] Add managed egress inventory defaults in ansible/group_vars/all.yml
- [ ] T011 [US1] Implement managed egress configuration tasks in ansible/roles/kube-vip/tasks/configure-egress.yml
- [ ] T012 [US1] Add managed egress manifest/config template in ansible/roles/kube-vip/templates/kube-vip-egress-configmap.yaml.j2
- [ ] T013 [US1] Integrate managed egress task include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T014 [US1] Implement invalid/conflicting opt-out fail-safe warnings in ansible/roles/kube-vip/tasks/configure-egress.yml
- [ ] T015 [US1] Document default-on egress and explicit opt-out examples in docs/ansible-k3s-baseline.md
- [ ] T016 [US1] Update story-specific validation procedure in specs/006-kube-vip-hardening/quickstart.md

**Checkpoint**: US1 is independently functional and validation-ready.

---

## Phase 4: User Story 2 - Reliable HA Service Addressing (Priority: P1)

**Goal**: Provide resilient service election with safe degraded behavior under quorum loss.

**Independent Test**: Create a LoadBalancer service, simulate quorum loss, and verify existing healthy leadership is held while new leadership changes are blocked.

- [ ] T017 [US2] Add service-election behavior variables in ansible/roles/kube-vip/defaults/main.yml
- [ ] T018 [US2] Implement service-election orchestration tasks in ansible/roles/kube-vip/tasks/configure-service-election.yml
- [ ] T019 [US2] Add service-election configuration template in ansible/roles/kube-vip/templates/kube-vip-service-election-config.yaml.j2
- [ ] T020 [US2] Integrate service-election include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T021 [US2] Emit degraded-state quorum-loss status in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T022 [US2] Update unified upgrade reconciliation for election state handling in ansible/playbooks/includes/upgrade-kube-vip.yml
- [ ] T023 [US2] Update quorum-loss validation steps in specs/006-kube-vip-hardening/quickstart.md

**Checkpoint**: US2 is independently functional and validation-ready.

---

## Phase 5: User Story 3 - Automatic Load Balancer Address Allocation (Priority: P2)

**Goal**: Enable DHCP-backed LoadBalancer allocation with pending-and-retry behavior during DHCP outages.

**Independent Test**: Create new LoadBalancer services with DHCP enabled, force temporary DHCP outage, and verify pending state with automatic retries and eventual allocation.

- [ ] T024 [US3] Add DHCP default-on variables and retry controls in ansible/roles/kube-vip/defaults/main.yml
- [ ] T025 [P] [US3] Add DHCP inventory defaults in ansible/group_vars/all.yml
- [ ] T026 [US3] Implement DHCP allocation lifecycle tasks in ansible/roles/kube-vip/tasks/configure-dhcp.yml
- [ ] T027 [US3] Add DHCP configuration template in ansible/roles/kube-vip/templates/kube-vip-dhcp-configmap.yaml.j2
- [ ] T028 [US3] Integrate DHCP include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T029 [US3] Add DHCP pending/retry operational status output in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T030 [US3] Update DHCP outage validation procedure in specs/006-kube-vip-hardening/quickstart.md

**Checkpoint**: US3 is independently functional and validation-ready.

---

## Phase 6: User Story 4 - Permission-Safe Operations (Priority: P2)

**Goal**: Enforce and reconcile a consolidated least-privilege RBAC baseline across deploy and upgrade paths.

**Independent Test**: Introduce controlled RBAC drift and confirm baseline is reconciled (or run fails with clear diagnostics) during site.yml execution.

- [ ] T031 [US4] Add RBAC baseline enforcement variables in ansible/roles/kube-vip/defaults/main.yml
- [ ] T032 [US4] Create consolidated RBAC baseline templates in ansible/roles/kube-vip/templates/kube-vip-rbac-baseline.yaml.j2
- [ ] T033 [US4] Implement RBAC drift-detection and reconcile tasks in ansible/roles/kube-vip/tasks/reconcile-rbac.yml
- [ ] T034 [US4] Integrate RBAC reconciliation include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T035 [US4] Integrate RBAC reconciliation into unified upgrades in ansible/playbooks/includes/upgrade-kube-vip.yml
- [ ] T036 [US4] Add RBAC can-i and baseline status reporting in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T037 [US4] Update RBAC drift validation procedure in specs/006-kube-vip-hardening/quickstart.md

**Checkpoint**: US4 is independently functional and validation-ready.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation alignment and end-to-end validation across stories.

- [ ] T038 [P] Align lifecycle entrypoint guidance (site.yml preferred, targeted alternatives retained) in specs/006-kube-vip-hardening/contracts/kube-vip-lifecycle-contracts.md
- [ ] T039 Run full feature validation walkthrough and evidence capture in specs/006-kube-vip-hardening/quickstart.md
- [ ] T040 [P] Document release/upgrade notes for kube-vip hardening in docs/ansible-k3s-baseline.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1): no dependencies.
- Foundational (Phase 2): depends on Setup and blocks all user stories.
- User Stories (Phases 3-6): all depend on Foundational completion.
- Polish (Phase 7): depends on completion of targeted user stories.

### User Story Dependencies

- US1 (P1): can start immediately after Foundational.
- US2 (P1): can start immediately after Foundational.
- US3 (P2): can start after Foundational; independent of US1 and US2.
- US4 (P2): can start after Foundational; independent of US1-US3 for implementation, but validates alongside them during final walkthrough.

### Suggested Delivery Order

- MVP slice: Setup -> Foundational -> US1 -> validate US1.
- HA networking slice: US2 -> validate US2.
- DHCP slice: US3 -> validate US3.
- Security hardening slice: US4 -> validate US4.

---

## Parallel Opportunities

- Phase 1: T003 can run in parallel with T001-T002.
- Phase 2: T007 can run in parallel with T004-T006.
- US1: T010 can run in parallel with T009; T016 can run after T011-T014.
- US3: T025 can run in parallel with T024; T030 can run after T026-T029.
- Polish: T038 and T040 can run in parallel before T039 closes validation.

---

## Parallel Example: User Story 1

```bash
# Parallel inventory/default preparation:
T009 ansible/roles/kube-vip/defaults/main.yml
T010 ansible/group_vars/all.yml

# Then complete behavior + wiring:
T011 ansible/roles/kube-vip/tasks/configure-egress.yml
T012 ansible/roles/kube-vip/templates/kube-vip-egress-configmap.yaml.j2
T013 ansible/roles/kube-vip/tasks/install.yml
T014 ansible/roles/kube-vip/tasks/configure-egress.yml
```

## Parallel Example: User Story 2

```bash
# Parallel configuration artifacts:
T017 ansible/roles/kube-vip/defaults/main.yml
T019 ansible/roles/kube-vip/templates/kube-vip-service-election-config.yaml.j2

# Then orchestration and status:
T018 ansible/roles/kube-vip/tasks/configure-service-election.yml
T020 ansible/roles/kube-vip/tasks/install.yml
T021 ansible/roles/kube-vip/tasks/report-status.yml
```

## Parallel Example: User Story 3

```bash
# Parallel defaults/inventory updates:
T024 ansible/roles/kube-vip/defaults/main.yml
T025 ansible/group_vars/all.yml

# Then DHCP lifecycle implementation:
T026 ansible/roles/kube-vip/tasks/configure-dhcp.yml
T027 ansible/roles/kube-vip/templates/kube-vip-dhcp-configmap.yaml.j2
T028 ansible/roles/kube-vip/tasks/install.yml
```

## Parallel Example: User Story 4

```bash
# Parallel RBAC baseline artifacts:
T031 ansible/roles/kube-vip/defaults/main.yml
T032 ansible/roles/kube-vip/templates/kube-vip-rbac-baseline.yaml.j2

# Then reconciliation and integration:
T033 ansible/roles/kube-vip/tasks/reconcile-rbac.yml
T034 ansible/roles/kube-vip/tasks/install.yml
T035 ansible/playbooks/includes/upgrade-kube-vip.yml
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. Validate US1 via site.yml flow and quickstart steps.

### Incremental Delivery

1. Deliver MVP (US1) for immediate firewall/egress operational value.
2. Add US2 for resilient HA service leadership behavior.
3. Add US3 for DHCP automation and outage-retry behavior.
4. Add US4 for RBAC hardening and drift reconciliation.
5. Run final cross-story walkthrough (T039).

### Team Parallelization

1. One engineer completes Setup + Foundational.
2. After checkpoint, parallelize by story:
   - Engineer A: US1
   - Engineer B: US2
   - Engineer C: US3
   - Engineer D: US4
3. Merge and execute Polish phase.

---

## Notes

- All tasks use explicit file paths and checklist format for direct execution.
- Story phases are independently testable through quickstart validation steps and site.yml workflows.
- cluster-core.yml and cluster-addons.yml are retained as targeted alternatives; site.yml remains the preferred execution path.
