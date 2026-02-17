---

description: "Implementation tasks for Baseline k3s Ansible Cluster Lifecycle"

---

# Tasks: Baseline k3s Ansible Cluster Lifecycle

**Input**: Design documents from `/specs/001-k3s-ansible-baseline/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in the specification; this tasks list focuses on implementation and smoke-validation tasks, not full TDD.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository and Ansible project scaffolding, aligned with the implementation plan.

- [X] T001 Create Ansible project root and base folders under ansible/
- [X] T002 [P] Create ansible/inventories/examples/ and ansible/inventories/production/ directories
- [X] T003 [P] Create ansible/group_vars/ and ansible/host_vars/ directories
- [X] T004 [P] Initialize ansible/playbooks/ directory with empty cluster-core.yml, cluster-addons.yml, scale-nodes.yml, and upgrade-k3s.yml placeholders
- [X] T005 [P] Initialize tests/ansible/ and tests/ansible/inventories/ and tests/ansible/smoke/ directories

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core structure that all user stories depend on (inventory model, base roles, and validation tooling).

**Note**: No user story work should begin until these tasks are complete.

- [X] T006 Define example HA inventory in ansible/inventories/examples/ha-cluster with k3s_servers and k3s_agents groups
- [X] T007 Define example single-node inventory in ansible/inventories/examples/single-node with k3s_servers only
- [X] T008 Create base group_vars files for cluster-wide settings in ansible/group_vars/all.yml
- [X] T009 [P] Create base group_vars for k3s_servers and k3s_agents in ansible/group_vars/k3s_servers.yml and ansible/group_vars/k3s_agents.yml
 - [X] T010 [P] Add README for Ansible layout, supported platforms, and host prerequisites in docs/ansible-structure.md
- [X] T011 Add minimal ansible-lint configuration in .ansible-lint.yml at repo root
- [X] T012 Add basic smoke playbook and inventory for tests in tests/ansible/smoke/smoke.yml and tests/ansible/inventories/local
- [X] T056 [P] Implement host prerequisite checks (supported OS, CPU/memory, required packages, ports, and network connectivity) in ansible/roles/k3s-common/ so playbooks fail fast with clear messages when requirements are not met

**Checkpoint**: Foundation ready – inventories, vars layout, and validation tooling exist.

---

## Phase 3: User Story 1 - Provision new HA k3s cluster (Priority: P1) 🎯 MVP

**Goal**: The core cluster playbook (cluster-core.yml) provisions a new HA k3s cluster with embedded etcd and a VIP-exposed control plane, while a separate add-ons playbook (cluster-addons.yml) applies selected platform add-ons (Traefik, cert-manager with DNS-01 issuers, multus, Rancher, rancher-monitoring, optional Synology CSI). Quickstart documentation demonstrates running only the core playbook for a minimal cluster and running both playbooks for the full baseline experience.

**Independent Test**: Run cluster-core.yml against the example HA inventory and verify core cluster creation and accessibility (including control-plane VIP via kube-vip or equivalent); when validating platform add-ons, additionally run cluster-addons.yml with add-ons enabled and verify add-on health and idempotent re-runs.

### Implementation for User Story 1

- [X] T013 [P] [US1] Scaffold k3s-common, k3s-server, and k3s-agent roles in ansible/roles/k3s-common/, ansible/roles/k3s-server/, ansible/roles/k3s-agent/
- [X] T014 [P] [US1] Integrate upstream k3s-io/k3s-ansible patterns into ansible/roles/k3s-common/ for host preparation tasks
- [X] T015 [P] [US1] Implement k3s-server role tasks for embedded etcd HA in ansible/roles/k3s-server/tasks/main.yml
- [X] T016 [P] [US1] Implement k3s-agent role tasks for joining worker nodes in ansible/roles/k3s-agent/tasks/main.yml
- [X] T017 [US1] Implement cluster-core.yml playbook to orchestrate k3s-common, k3s-server, and k3s-agent roles in ansible/playbooks/cluster-core.yml
- [X] T018 [P] [US1] Scaffold cert-manager role directory in ansible/roles/cert-manager/
- [X] T019 [P] [US1] Implement cert-manager installation and CRDs deployment tasks in ansible/roles/cert-manager/tasks/main.yml
- [X] T020 [P] [US1] Implement DNS-01 provider-agnostic ClusterIssuer templates in ansible/roles/cert-manager/templates/ with variables from ansible/group_vars/
- [X] T021 [P] [US1] Scaffold multus role directory in ansible/roles/multus/
- [X] T022 [P] [US1] Implement multus installation and NetworkAttachmentDefinition rendering in ansible/roles/multus/tasks/main.yml
- [X] T023 [P] [US1] Scaffold Rancher role directory in ansible/roles/rancher/
- [X] T024 [P] [US1] Implement Rancher Helm-based deployment tasks in ansible/roles/rancher/tasks/main.yml
- [X] T025 [P] [US1] Scaffold rancher-monitoring role directory in ansible/roles/rancher-monitoring/
- [X] T026 [P] [US1] Implement rancher-monitoring Helm-based deployment tasks in ansible/roles/rancher-monitoring/tasks/main.yml
- [X] T027 [P] [US1] Scaffold Traefik role directory in ansible/roles/traefik/
- [X] T028 [P] [US1] Implement Traefik configuration and deployment tasks in ansible/roles/traefik/tasks/main.yml
- [X] T029 [P] [US1] Scaffold optional Synology CSI role directory in ansible/roles/synology-csi/
- [X] T030 [P] [US1] Implement Synology CSI deployment and StorageClass configuration tasks in ansible/roles/synology-csi/tasks/main.yml
- [X] T031 [US1] Implement cluster-addons.yml playbook to orchestrate add-on roles (cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI) in ansible/playbooks/cluster-addons.yml
- [X] T032 [US1] Add validation tasks in cluster-core.yml and cluster-addons.yml to check node readiness, cluster state, add-on health, and VIP accessibility (control-plane and service load balancers)
- [X] T057 [P] [US1] Scaffold kube-vip role directory in ansible/roles/kube-vip/ for control-plane VIP and service load balancer configuration
- [X] T058 [P] [US1] Implement kube-vip deployment and configuration tasks (control-plane VIP, service LB address pool) in ansible/roles/kube-vip/tasks/main.yml driven by variables
- [X] T059 [US1] Wire kube-vip role into cluster-core.yml (for control-plane VIP) and, where appropriate, cluster-addons.yml or Traefik configuration (for service load balancer behavior)
- [X] T033 [US1] Document example HA and single-node flows in specs/001-k3s-ansible-baseline/quickstart.md (update with final role and playbook names)

**Checkpoint**: User Story 1 can be validated independently using example inventories and quickstart instructions.

---

## Phase 4: User Story 2 - Update existing cluster configuration (Priority: P2)

**Goal**: Re-running cluster-core.yml and/or cluster-addons.yml with updated variables applies configuration changes to core cluster settings and to add-ons (cert-manager, multus, Rancher, monitoring, Traefik, optional Synology CSI) without recreating the cluster.

**Independent Test**: Change selected variables (e.g., DNS-01 provider settings, Rancher hostname, multus VLANs, kube-vip VIP or address pool) and run cluster-core.yml and/or cluster-addons.yml, as appropriate, to verify in-place updates only.

### Implementation for User Story 2

- [ ] T034 [P] [US2] Ensure cert-manager role uses idempotent module calls and `state: present` semantics in ansible/roles/cert-manager/tasks/main.yml
- [ ] T035 [P] [US2] Add tasks to update existing ClusterIssuer resources on variable changes in ansible/roles/cert-manager/tasks/main.yml
- [ ] T036 [P] [US2] Ensure multus NetworkAttachmentDefinitions are rendered and updated from vars without destructive recreation in ansible/roles/multus/tasks/main.yml
- [ ] T037 [P] [US2] Implement Rancher configuration updates (hostname, TLS, values) through Helm upgrade semantics in ansible/roles/rancher/tasks/main.yml
- [ ] T038 [P] [US2] Implement rancher-monitoring configuration updates via Helm upgrade in ansible/roles/rancher-monitoring/tasks/main.yml
- [ ] T039 [P] [US2] Implement Traefik configuration updates via Helm upgrade or manifest patching in ansible/roles/traefik/tasks/main.yml
- [ ] T040 [P] [US2] Implement Synology CSI configuration updates (storage classes, parameters) in ansible/roles/synology-csi/tasks/main.yml
- [ ] T041 [US2] Add variable-driven guards in cluster-addons.yml to ensure add-on roles run conditionally based on enabled components in ansible/playbooks/cluster-addons.yml
- [ ] T042 [US2] Add idempotence-focused smoke scenario in tests/ansible/smoke/smoke.yml to run cluster-core.yml and cluster-addons.yml twice and verify clean convergence

**Checkpoint**: User Story 2 validated by modifying vars and re-running cluster-core.yml and, where needed, cluster-addons.yml without disruptive changes.

---

## Phase 5: User Story 3 - Manage control-plane and worker nodes (Priority: P3)

**Goal**: Add and remove control-plane and worker nodes through inventory and vars using scale-nodes.yml, while maintaining cluster health and etcd quorum where applicable.

**Independent Test**: Start from a working cluster, adjust inventory to add/remove nodes, run scale-nodes.yml, and verify cluster membership changes as expected.

### Implementation for User Story 3

- [ ] T043 [P] [US3] Implement logic in scale-nodes.yml to detect new vs removed nodes from inventory in ansible/playbooks/scale-nodes.yml
- [ ] T044 [P] [US3] Add tasks to join new control-plane nodes using k3s-server role in ansible/playbooks/scale-nodes.yml
- [ ] T045 [P] [US3] Add tasks to join new worker nodes using k3s-agent role in ansible/playbooks/scale-nodes.yml
- [ ] T046 [P] [US3] Implement node drain and cordon behavior for removal candidates in ansible/playbooks/scale-nodes.yml
- [ ] T047 [US3] Add safeguards and checks to preserve embedded etcd quorum when removing control-plane nodes in ansible/playbooks/scale-nodes.yml
- [ ] T048 [US3] Add validation tasks to confirm updated node list and scheduling on new workers in ansible/playbooks/scale-nodes.yml
- [ ] T049 [US3] Add scale-related smoke scenario in tests/ansible/smoke/smoke.yml to exercise add/remove flows

**Checkpoint**: User Story 3 validated by inventory-driven add/remove operations on control-plane and worker nodes.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cross-story improvements, documentation, and hardening.

 - [ ] T050 [P] Add detailed README for the Ansible project in docs/ansible-k3s-baseline.md, including supported environments, scale assumptions, and explicit non-goals (e.g., full DR orchestration)
- [ ] T051 [P] Refine example inventories and vars to match real-world defaults in ansible/inventories/examples/ and ansible/group_vars/
- [ ] T052 Code cleanup and role refactoring across ansible/roles/* for consistency and reuse
- [ ] T053 [P] Add additional smoke validations (e.g., basic kubectl checks) in tests/ansible/smoke/smoke.yml
- [ ] T054 [P] Verify quickstart flows end-to-end and update specs/001-k3s-ansible-baseline/quickstart.md as needed
- [ ] T055 Security and hardening pass (review of secrets handling, TLS defaults, firewall assumptions) across ansible/ roles and playbooks

---

## Phase 7: Minor/Patch Upgrade Flow

**Purpose**: Implement and validate the dedicated minor/patch k3s upgrade playbook.

- [ ] T060 [P] Implement upgrade-k3s.yml playbook in ansible/playbooks/upgrade-k3s.yml to perform rolling minor/patch upgrades based on a k3s_version variable, ensuring only compatible version changes are attempted
- [ ] T061 [P] Add upgrade tasks to verify node readiness and confirm that all servers and agents report the desired k3s_version after upgrade in ansible/playbooks/upgrade-k3s.yml
- [ ] T062 [P] Add an upgrade-focused smoke scenario in tests/ansible/smoke/smoke.yml that runs upgrade-k3s.yml against an example inventory and asserts successful completion without prolonged control-plane downtime

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 – Setup**: No dependencies; must be completed before foundational wiring and user story implementation.
- **Phase 2 – Foundational**: Depends on Phase 1; blocks all user stories until inventories, vars, and lint/smoke scaffolding exist.
- **Phase 3 – User Story 1 (P1)**: Depends on Phase 2; establishes the MVP cluster provisioning path.
- **Phase 4 – User Story 2 (P2)**: Depends on completion of User Story 1; operates on clusters already provisioned by the core cluster playbook (cluster-core.yml).
- **Phase 5 – User Story 3 (P3)**: Depends on completion of User Story 1; uses the same roles to scale nodes.
- **Phase 6 – Polish**: Depends on all targeted user stories being implemented.

### User Story Dependencies

- **US1 (Provision new HA k3s cluster)**: Depends only on Setup and Foundational phases; can be implemented independently.
- **US2 (Update existing cluster configuration)**: Depends on US1, since it assumes a cluster created and managed by the core cluster playbook (cluster-core.yml).
- **US3 (Manage control-plane and worker nodes)**: Depends on US1, as it reuses k3s roles and the baseline cluster lifecycle path.

### Within Each User Story

- Core roles and playbooks (k3s-common, k3s-server, k3s-agent, cluster-core.yml) must be in place before enabling higher-level add-ons and scale/upgrade flows.
- Add-ons (cert-manager, multus, Rancher, monitoring, Traefik, Synology CSI) can be developed largely in parallel once the cluster lifecycle roles are available.
- Scale operations (US3) must be wired after core cluster provisioning is stable.

### Parallel Execution Examples

- During **Phase 1–2**, tasks marked [P] (T002–T005, T009–T010) can be implemented in parallel, as they touch different directories.
- For **US1**, role scaffolding and implementations for cert-manager, multus, Rancher, rancher-monitoring, Traefik, and Synology CSI (T018–T030) can proceed in parallel while T017 and T031 integrate them via cluster-core.yml and cluster-addons.yml.
- For **US2**, idempotence updates across roles (T034–T040) can be done in parallel, then add-ons playbook wiring (T041) and the smoke scenario (T042) follow.
- For **US3**, joining/removal logic tasks (T043–T046) can be worked on in parallel before adding safeguards and validations (T047–T048).

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Implement Phase 3 (US1) tasks T013–T033 and T057–T059 to achieve a working HA k3s cluster using cluster-core.yml for the core cluster, kube-vip for VIP/LB behavior, and cluster-addons.yml for optional baseline add-ons.
3. Validate using example inventories and quickstart instructions.

### Incremental Delivery

1. Deliver US1 as the initial MVP.
2. Add US2 to support configuration updates via re-running cluster-core.yml and cluster-addons.yml, including kube-vip VIP/LB and add-on configuration.
3. Add US3 to support inventory-driven scaling of control-plane and worker nodes.
4. Apply Phase 6 polish tasks for documentation, refactoring, and security review.

### Team Parallelization

- One contributor can focus on k3s core roles and cluster-core.yml (T013–T017, T031–T032, T059).
- Others can implement add-on roles (T018–T030) in parallel.
- Subsequent contributors can focus on update behavior (US2) and scaling logic (US3) while the core path stabilizes.
