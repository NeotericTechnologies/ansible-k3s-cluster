---

description: "Implementation tasks for Baseline k3s Ansible Cluster Lifecycle"

---

# Tasks: Baseline k3s Ansible Cluster Lifecycle

**Input**: Design documents from `/specs/001-k3s-ansible-baseline/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test tasks are limited to smoke and validation workflows because full TDD was not explicitly requested.

**Organization**: Tasks are grouped by user story to enable independent implementation and verification.

## Phase 1: Setup (Project Initialization)

**Purpose**: Ensure entrypoint playbooks, role skeletons, and inventory scaffolding are aligned to the updated plan.

- [ ] T001 Normalize core and add-on playbook entrypoints in ansible/playbooks/cluster-core.yml and ansible/playbooks/cluster-addons.yml
- [ ] T002 [P] Normalize lifecycle playbook entrypoints in ansible/playbooks/scale-nodes.yml and ansible/playbooks/upgrade-k3s.yml
- [ ] T003 [P] Align baseline inventory examples in ansible/inventories/examples/ha-cluster/hosts.ini and ansible/inventories/examples/single-node/hosts.ini
- [ ] T004 [P] Align baseline group variables in ansible/group_vars/all.yml, ansible/group_vars/k3s_servers.yml, and ansible/group_vars/k3s_agents.yml
- [ ] T005 Refresh smoke inventory defaults in tests/ansible/inventories/local

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement shared prerequisites that all user stories depend on.

**CRITICAL**: Complete this phase before starting user story implementation.

- [ ] T006 Implement fail-fast host prerequisite validation in ansible/roles/k3s-common/tasks/prerequisites.yml
- [ ] T007 Add shared dependency preparation tasks in ansible/roles/k3s-common/tasks/dependencies.yml
- [ ] T008 [P] Wire prerequisite and dependency includes in ansible/roles/k3s-common/tasks/main.yml
- [ ] T009 Define shared kubeconfig and API endpoint defaults in ansible/roles/k3s-server/defaults/main.yml
- [ ] T010 [P] Define shared agent join defaults in ansible/roles/k3s-agent/defaults/main.yml
- [ ] T011 Add common lifecycle assertions in ansible/playbooks/cluster-core.yml for platform support, role groups, and required variables

**Checkpoint**: Foundation complete; user stories can proceed.

---

## Phase 3: User Story 1 - Provision new HA k3s cluster (Priority: P1)

**Goal**: Provision a new HA embedded-etcd k3s cluster and optional add-ons, with kube-vip installed as a DaemonSet for stable control-plane and service endpoints.

**Independent Test**: Run ansible/playbooks/cluster-core.yml against the HA example inventory, verify cluster health and kube-vip DaemonSet readiness, then run ansible/playbooks/cluster-addons.yml with enabled add-ons and verify component availability.

### Implementation for User Story 1

- [ ] T012 [P] [US1] Implement server installation workflow in ansible/roles/k3s-server/tasks/install.yml
- [ ] T013 [P] [US1] Implement server role orchestration in ansible/roles/k3s-server/tasks/main.yml
- [ ] T014 [P] [US1] Implement kubeconfig materialization for operators in ansible/roles/k3s-server/tasks/kubeconfig.yml
- [ ] T015 [P] [US1] Implement agent installation workflow in ansible/roles/k3s-agent/tasks/install.yml
- [ ] T016 [P] [US1] Implement agent role orchestration in ansible/roles/k3s-agent/tasks/main.yml
- [ ] T017 [P] [US1] Define kube-vip DaemonSet defaults in ansible/roles/kube-vip/defaults/main.yml
- [ ] T018 [P] [US1] Implement kube-vip DaemonSet install workflow in ansible/roles/kube-vip/tasks/install.yml
- [ ] T019 [US1] Wire kube-vip DaemonSet role execution in ansible/roles/kube-vip/tasks/main.yml
- [ ] T020 [US1] Integrate k3s-common, k3s-server, k3s-agent, and kube-vip roles in ansible/playbooks/cluster-core.yml
- [ ] T021 [P] [US1] Implement cert-manager install workflow in ansible/roles/cert-manager/tasks/install.yml
- [ ] T022 [P] [US1] Implement provider-agnostic issuer rendering in ansible/roles/cert-manager/templates/clusterissuer-staging.yaml.j2 and ansible/roles/cert-manager/templates/clusterissuer-production.yaml.j2
- [ ] T023 [P] [US1] Implement multus install and NAD rendering in ansible/roles/multus/tasks/main.yml
- [ ] T024 [P] [US1] Implement Traefik deployment workflow in ansible/roles/traefik/tasks/main.yml
- [ ] T025 [P] [US1] Implement Rancher deployment workflow in ansible/roles/rancher/tasks/main.yml
- [ ] T026 [P] [US1] Implement rancher-monitoring deployment workflow in ansible/roles/rancher-monitoring/tasks/main.yml
- [ ] T027 [P] [US1] Implement optional Synology CSI deployment workflow in ansible/roles/synology-csi/tasks/main.yml
- [ ] T028 [US1] Integrate add-on roles with enablement guards in ansible/playbooks/cluster-addons.yml
- [ ] T029 [US1] Add provisioning smoke scenario for HA plus add-ons in tests/ansible/smoke/smoke.yml

**Checkpoint**: US1 is independently deliverable and verifiable.

---

## Phase 4: User Story 2 - Update existing cluster configuration (Priority: P2)

**Goal**: Apply configuration changes safely by re-running core and/or add-on playbooks without rebuilding clusters.

**Independent Test**: Modify variables for DNS provider, kube-vip address settings, and selected add-on values, rerun playbooks, and verify only intended resources converge.

### Implementation for User Story 2

- [ ] T030 [P] [US2] Implement cert-manager reconciliation for issuer updates in ansible/roles/cert-manager/tasks/main.yml
- [ ] T031 [P] [US2] Implement multus reconciliation for VLAN and NAD updates in ansible/roles/multus/tasks/main.yml
- [ ] T032 [P] [US2] Implement Traefik Helm values reconciliation in ansible/roles/traefik/tasks/main.yml
- [ ] T033 [P] [US2] Implement Rancher Helm values reconciliation in ansible/roles/rancher/tasks/main.yml
- [ ] T034 [P] [US2] Implement rancher-monitoring values reconciliation in ansible/roles/rancher-monitoring/tasks/main.yml
- [ ] T035 [P] [US2] Implement Synology CSI storage class reconciliation in ansible/roles/synology-csi/tasks/main.yml
- [ ] T036 [US2] Implement kube-vip DaemonSet update reconciliation in ansible/roles/kube-vip/tasks/main.yml
- [ ] T037 [US2] Add idempotence and reconfiguration smoke scenario in tests/ansible/smoke/idempotence-test.yml

**Checkpoint**: US2 is independently deliverable and verifiable.

---

## Phase 5: User Story 3 - Manage control-plane and worker nodes (Priority: P3)

**Goal**: Scale nodes up and down safely while preserving control-plane and etcd quorum guarantees.

**Independent Test**: Add and remove server/agent hosts in inventory and run ansible/playbooks/scale-nodes.yml to verify correct joins, drains, removals, and cluster health.

### Implementation for User Story 3

- [ ] T038 [P] [US3] Implement inventory delta detection for node add/remove in ansible/playbooks/scale-nodes.yml
- [ ] T039 [P] [US3] Implement server join flow reuse from k3s-server role in ansible/playbooks/scale-nodes.yml
- [ ] T040 [P] [US3] Implement agent join flow reuse from k3s-agent role in ansible/playbooks/scale-nodes.yml
- [ ] T041 [US3] Implement drain and safe removal workflow in ansible/playbooks/scale-nodes.yml
- [ ] T042 [US3] Implement etcd quorum guardrails for server removal in ansible/playbooks/scale-nodes.yml
- [ ] T043 [US3] Add scaling smoke scenario in tests/ansible/smoke/scale-test.yml

**Checkpoint**: US3 is independently deliverable and verifiable.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Complete documentation, upgrade flow, security hardening, and end-to-end validation.

- [ ] T044 [P] Update operator baseline documentation in docs/ansible-k3s-baseline.md
- [ ] T045 [P] Update repository structure and variable guidance in docs/ansible-structure.md
- [ ] T046 Update feature quickstart verification steps in specs/001-k3s-ansible-baseline/quickstart.md
- [ ] T047 [P] Implement controlled minor/patch rolling upgrade flow in ansible/playbooks/upgrade-k3s.yml
- [ ] T048 [P] Add upgrade smoke scenario in tests/ansible/smoke/upgrade-test.yml
- [ ] T049 [P] Add cross-story smoke orchestration updates in tests/ansible/smoke/smoke.yml
- [ ] T050 Perform final security and secret-handling review across ansible/group_vars/all.yml and ansible/roles/

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (Setup) has no dependencies.
- Phase 2 (Foundational) depends on Phase 1 and blocks all user story work.
- Phase 3 (US1) depends on Phase 2.
- Phase 4 (US2) depends on Phase 3.
- Phase 5 (US3) depends on Phase 3.
- Final Phase depends on completion of targeted user stories.

### User Story Dependencies

- US1: Starts after Foundational completion; no dependency on other user stories.
- US2: Depends on US1 because it updates an existing provisioned cluster.
- US3: Depends on US1 because it scales an existing provisioned cluster.

### Dependency Graph

- Setup -> Foundational -> US1 -> US2
- Setup -> Foundational -> US1 -> US3
- US2 + US3 -> Final Phase

### Parallel Opportunities

- Setup: T002, T003, and T004 can run in parallel.
- Foundational: T008 and T010 can run in parallel after T006 and T007 begin.
- US1: T012-T018 and T021-T027 are mostly parallel role-level work across separate files.
- US2: T030-T035 can run in parallel, then T036 and T037 follow.
- US3: T038-T040 can run in parallel, then T041-T043 follow.
- Final: T044, T045, T047, T048, and T049 can run in parallel.

## Parallel Example: User Story 1

```bash
# Parallel role implementation tasks for US1
Task T012 in ansible/roles/k3s-server/tasks/install.yml
Task T015 in ansible/roles/k3s-agent/tasks/install.yml
Task T018 in ansible/roles/kube-vip/tasks/install.yml
Task T021 in ansible/roles/cert-manager/tasks/install.yml
Task T023 in ansible/roles/multus/tasks/main.yml
Task T024 in ansible/roles/traefik/tasks/main.yml
Task T025 in ansible/roles/rancher/tasks/main.yml
Task T026 in ansible/roles/rancher-monitoring/tasks/main.yml
Task T027 in ansible/roles/synology-csi/tasks/main.yml
```

## Implementation Strategy

### MVP First (US1)

1. Complete Phase 1 and Phase 2.
2. Complete all US1 tasks (T012-T029).
3. Validate independent US1 acceptance before moving forward.

### Incremental Delivery

1. Deliver US1 provisioning baseline with kube-vip DaemonSet.
2. Deliver US2 update/reconciliation behavior.
3. Deliver US3 node scaling behavior.
4. Complete polish and upgrade flow.
