# Tasks: Kube-VIP Hardening

**Input**: Design documents from `/specs/006-kube-vip-hardening/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Automated validation is explicitly required by the specification. This task list includes automated test tasks for each user story.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label (US1, US2, US3, US4)
- Every task includes an explicit file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare feature scaffolding, test directories, and default variable surfaces used by all stories.

- [ ] T001 Create kube-vip hardening variable scaffolding in ansible/roles/kube-vip/defaults/main.yml
- [ ] T002 Add hardening defaults (including default-on egress and DHCP) in ansible/group_vars/all.yml
- [ ] T003 [P] Create integration test directory structure in tests/ansible/integration/kube_vip_hardening/
- [ ] T004 [P] Add feature overview section for kube-vip hardening in docs/ansible-k3s-baseline.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared orchestration, status plumbing, and common validation harness required before user story work.

**CRITICAL**: No user story implementation starts until this phase is complete.

- [ ] T005 Create shared kube-vip config validation tasks in ansible/roles/kube-vip/tasks/validate-config.yml
- [ ] T006 Create shared kube-vip status reporting tasks in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T007 Refactor role entry flow to include shared validation/reporting in ansible/roles/kube-vip/tasks/install.yml
- [ ] T008 [P] Add shared hardening runtime config template in ansible/roles/kube-vip/templates/kube-vip-hardening-configmap.yaml.j2
- [ ] T009 Wire hardening reconciliation into unified upgrades in ansible/playbooks/includes/upgrade-kube-vip.yml
- [ ] T010 Create common test helper playbook for kube-vip hardening scenarios in tests/ansible/integration/kube_vip_hardening/helpers.yml
- [ ] T011 [P] Create fresh-deploy automated validation runner in tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
- [ ] T012 [P] Create upgrade-path automated validation runner in tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml

**Checkpoint**: Foundation complete. User stories can now proceed.

---

## Phase 3: User Story 1 - Stable Cluster Egress Identity (Priority: P1) MVP

**Goal**: Deliver default-on managed egress with explicit opt-out and fail-safe handling for invalid opt-out configuration.

**Independent Test**: Run site.yml and automated egress validations to verify default managed egress, valid opt-out behavior, and invalid opt-out fail-safe warnings.

### Tests for User Story 1

- [ ] T013 [P] [US1] Add automated egress default behavior scenario in tests/ansible/integration/kube_vip_hardening/test_egress_default.yml
- [ ] T014 [P] [US1] Add automated valid opt-out scenario in tests/ansible/integration/kube_vip_hardening/test_egress_opt_out_valid.yml
- [ ] T015 [P] [US1] Add automated invalid opt-out fail-safe scenario in tests/ansible/integration/kube_vip_hardening/test_egress_opt_out_invalid.yml

### Implementation for User Story 1

- [ ] T016 [US1] Add managed egress variable definitions in ansible/roles/kube-vip/defaults/main.yml
- [ ] T017 [P] [US1] Add managed egress inventory defaults in ansible/group_vars/all.yml
- [ ] T018 [US1] Implement managed egress configuration tasks in ansible/roles/kube-vip/tasks/configure-egress.yml
- [ ] T019 [US1] Add managed egress config template in ansible/roles/kube-vip/templates/kube-vip-egress-configmap.yaml.j2
- [ ] T020 [US1] Integrate managed egress include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T021 [US1] Implement invalid/conflicting opt-out fail-safe warnings in ansible/roles/kube-vip/tasks/configure-egress.yml
- [ ] T022 [US1] Add egress validation execution to fresh-deploy runner in tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
- [ ] T023 [US1] Add egress validation execution to upgrade-path runner in tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml

**Checkpoint**: US1 is independently functional and validation-ready.

---

## Phase 4: User Story 2 - Reliable HA Service Addressing (Priority: P1)

**Goal**: Provide resilient service election with safe degraded behavior under quorum loss.

**Independent Test**: Create a LoadBalancer service, simulate quorum loss, and verify existing healthy leadership is held while new leadership changes are blocked.

### Tests for User Story 2

- [ ] T024 [P] [US2] Add automated election healthy-path scenario in tests/ansible/integration/kube_vip_hardening/test_election_healthy.yml
- [ ] T025 [P] [US2] Add automated quorum-loss degraded-state scenario in tests/ansible/integration/kube_vip_hardening/test_election_quorum_loss.yml

### Implementation for User Story 2

- [ ] T026 [US2] Add service-election variables in ansible/roles/kube-vip/defaults/main.yml
- [ ] T027 [US2] Implement service-election orchestration tasks in ansible/roles/kube-vip/tasks/configure-service-election.yml
- [ ] T028 [US2] Add service-election configuration template in ansible/roles/kube-vip/templates/kube-vip-service-election-config.yaml.j2
- [ ] T029 [US2] Integrate service-election include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T030 [US2] Emit degraded-state quorum-loss status in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T031 [US2] Add election validation execution to fresh-deploy runner in tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
- [ ] T032 [US2] Add election validation execution to upgrade-path runner in tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml

**Checkpoint**: US2 is independently functional and validation-ready.

---

## Phase 5: User Story 3 - Automatic Load Balancer Address Allocation (Priority: P2)

**Goal**: Enable DHCP-backed LoadBalancer allocation with pending-and-retry behavior during DHCP outages, including lease renewal handling.

**Independent Test**: Create DHCP-backed LoadBalancer services, force temporary DHCP outage, and verify pending state with automatic retries, allocation, and renewal behavior.

### Tests for User Story 3

- [ ] T033 [P] [US3] Add automated DHCP acquisition scenario in tests/ansible/integration/kube_vip_hardening/test_dhcp_acquisition.yml
- [ ] T034 [P] [US3] Add automated DHCP outage retry scenario in tests/ansible/integration/kube_vip_hardening/test_dhcp_retry.yml
- [ ] T035 [P] [US3] Add automated DHCP renewal scenario in tests/ansible/integration/kube_vip_hardening/test_dhcp_renewal.yml

### Implementation for User Story 3

- [ ] T036 [US3] Add DHCP default-on variables and retry controls in ansible/roles/kube-vip/defaults/main.yml
- [ ] T037 [P] [US3] Add DHCP inventory defaults in ansible/group_vars/all.yml
- [ ] T038 [US3] Implement DHCP lifecycle tasks in ansible/roles/kube-vip/tasks/configure-dhcp.yml
- [ ] T039 [US3] Add DHCP configuration template in ansible/roles/kube-vip/templates/kube-vip-dhcp-configmap.yaml.j2
- [ ] T040 [US3] Integrate DHCP include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T041 [US3] Add DHCP pending/retry/renewal status output in ansible/roles/kube-vip/tasks/report-status.yml
- [ ] T042 [US3] Add DHCP validation execution to fresh-deploy runner in tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
- [ ] T043 [US3] Add DHCP validation execution to upgrade-path runner in tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml

**Checkpoint**: US3 is independently functional and validation-ready.

---

## Phase 6: User Story 4 - Permission-Safe Operations (Priority: P2)

**Goal**: Enforce and reconcile a consolidated least-privilege RBAC baseline across deploy and upgrade paths.

**Independent Test**: Introduce controlled RBAC drift and confirm baseline is reconciled (or run fails with clear diagnostics) during site.yml execution.

### Tests for User Story 4

- [ ] T044 [P] [US4] Add automated RBAC baseline conformance scenario in tests/ansible/integration/kube_vip_hardening/test_rbac_baseline.yml
- [ ] T045 [P] [US4] Add automated RBAC drift reconciliation scenario in tests/ansible/integration/kube_vip_hardening/test_rbac_reconcile.yml

### Implementation for User Story 4

- [ ] T046 [US4] Add RBAC baseline enforcement variables in ansible/roles/kube-vip/defaults/main.yml
- [ ] T047 [US4] Create consolidated RBAC baseline template in ansible/roles/kube-vip/templates/kube-vip-rbac-baseline.yaml.j2
- [ ] T048 [US4] Implement RBAC drift-detection and reconcile tasks in ansible/roles/kube-vip/tasks/reconcile-rbac.yml
- [ ] T049 [US4] Integrate RBAC reconciliation include into role flow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T050 [US4] Integrate RBAC reconciliation into unified upgrades in ansible/playbooks/includes/upgrade-kube-vip.yml
- [ ] T051 [US4] Add RBAC validation execution to fresh-deploy runner in tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
- [ ] T052 [US4] Add RBAC validation execution to upgrade-path runner in tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml

**Checkpoint**: US4 is independently functional and validation-ready.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation alignment and end-to-end validation across stories.

- [ ] T053 [P] Align lifecycle and automated validation guidance in specs/006-kube-vip-hardening/contracts/kube-vip-lifecycle-contracts.md
- [ ] T054 [P] Align automated validation execution and evidence sections in specs/006-kube-vip-hardening/quickstart.md
- [ ] T055 Run full fresh-deploy and upgrade-path automated validation walkthrough in specs/006-kube-vip-hardening/quickstart.md
- [ ] T056 [P] Document release and upgrade notes for kube-vip hardening in docs/ansible-k3s-baseline.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1): no dependencies.
- Foundational (Phase 2): depends on Setup and blocks all user stories.
- User Stories (Phases 3-6): all depend on Foundational completion.
- Polish (Phase 7): depends on completion of targeted user stories.

### User Story Dependencies

- US1 (P1): starts after Foundational.
- US2 (P1): starts after Foundational.
- US3 (P2): starts after Foundational.
- US4 (P2): starts after Foundational.

### Suggested Delivery Order

- MVP slice: Setup -> Foundational -> US1 -> validate US1.
- HA leadership slice: US2 -> validate US2.
- DHCP lifecycle slice: US3 -> validate US3.
- RBAC hardening slice: US4 -> validate US4.

---

## Parallel Opportunities

- Phase 1: T003 and T004 are parallelizable with T001-T002.
- Phase 2: T008, T011, and T012 can run in parallel after T005-T007 starts.
- US1 tests: T013, T014, and T015 run in parallel.
- US2 tests: T024 and T025 run in parallel.
- US3 tests: T033, T034, and T035 run in parallel.
- US4 tests: T044 and T045 run in parallel.
- Polish: T053, T054, and T056 run in parallel before T055 closes.

---

## Parallel Example: User Story 1

```bash
# Run US1 automated test scenarios together:
T013 tests/ansible/integration/kube_vip_hardening/test_egress_default.yml
T014 tests/ansible/integration/kube_vip_hardening/test_egress_opt_out_valid.yml
T015 tests/ansible/integration/kube_vip_hardening/test_egress_opt_out_invalid.yml

# Prepare defaults in parallel:
T016 ansible/roles/kube-vip/defaults/main.yml
T017 ansible/group_vars/all.yml
```

## Parallel Example: User Story 2

```bash
# Run US2 automated election scenarios together:
T024 tests/ansible/integration/kube_vip_hardening/test_election_healthy.yml
T025 tests/ansible/integration/kube_vip_hardening/test_election_quorum_loss.yml

# Implement election artifacts:
T027 ansible/roles/kube-vip/tasks/configure-service-election.yml
T028 ansible/roles/kube-vip/templates/kube-vip-service-election-config.yaml.j2
```

## Parallel Example: User Story 3

```bash
# Run US3 automated DHCP scenarios together:
T033 tests/ansible/integration/kube_vip_hardening/test_dhcp_acquisition.yml
T034 tests/ansible/integration/kube_vip_hardening/test_dhcp_retry.yml
T035 tests/ansible/integration/kube_vip_hardening/test_dhcp_renewal.yml

# Implement DHCP artifacts:
T038 ansible/roles/kube-vip/tasks/configure-dhcp.yml
T039 ansible/roles/kube-vip/templates/kube-vip-dhcp-configmap.yaml.j2
```

## Parallel Example: User Story 4

```bash
# Run US4 automated RBAC scenarios together:
T044 tests/ansible/integration/kube_vip_hardening/test_rbac_baseline.yml
T045 tests/ansible/integration/kube_vip_hardening/test_rbac_reconcile.yml

# Implement RBAC artifacts:
T047 ansible/roles/kube-vip/templates/kube-vip-rbac-baseline.yaml.j2
T048 ansible/roles/kube-vip/tasks/reconcile-rbac.yml
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. Validate US1 through site.yml and US1 automated scenarios.

### Incremental Delivery

1. Deliver US1 for immediate firewall and egress value.
2. Deliver US2 for resilient leader-election behavior.
3. Deliver US3 for DHCP acquisition/retry/renewal behavior.
4. Deliver US4 for RBAC hardening and drift reconciliation.
5. Execute final cross-story automated validation (T055).

### Parallel Team Strategy

1. Team completes Setup + Foundational first.
2. After checkpoint, parallelize by story ownership:
   - Engineer A: US1
   - Engineer B: US2
   - Engineer C: US3
   - Engineer D: US4
3. Merge and run Polish phase.

---

## Notes

- All tasks use explicit file paths and strict checklist format.
- Automated validation is included because the spec explicitly requires feasible automated coverage.
- site.yml remains the preferred execution path, while cluster-core.yml and cluster-addons.yml are retained for targeted operations.
