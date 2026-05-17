---

description: "Implementation tasks for Baseline k3s Ansible Cluster Lifecycle"

---

# Tasks: Baseline k3s Ansible Cluster Lifecycle

**Input**: Design documents from `specs/001-k3s-ansible-baseline/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Smoke test playbooks included in Final Phase — no TDD approach requested.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## k3s Deployment Compatibility Constraints (Cross-Cutting)

All tasks MUST comply with these constraints per R-013:

1. **No symlinks on nodes** — roles must not create symlinks on target nodes for any deployment artifact
2. **No file copies to nodes for runtime workloads** — add-ons (kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI) must be deployed as in-cluster resources via the Kubernetes API (Helm charts, manifests via `kubernetes.core` modules), not by copying files to the node filesystem
3. **No modification of default k3s paths** — roles must not remove, rename, or alter paths managed by k3s (`/var/lib/rancher/k3s`, `/etc/rancher/k3s`, etc.)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, dependency declarations, and base configuration structure

- [X] T001 Create Ansible collections requirements file in ansible/requirements.yml (kubernetes.core, community.kubernetes); document that custom roles (k3s-server, k3s-agent, k3s-common) supersede k3s-io/k3s-ansible with patterns reused per research R-005
- [X] T002 [P] Define cluster-wide variable defaults (ClusterConfig, NetworkConfig) in ansible/group_vars/all.yml
- [X] T003 [P] Define server-specific variable defaults in ansible/group_vars/k3s_servers.yml
- [X] T004 [P] Define agent-specific variable defaults in ansible/group_vars/k3s_agents.yml
- [X] T005 [P] Create HA cluster example inventory in ansible/inventories/examples/ha-cluster/hosts.ini
- [X] T006 [P] Create single-node example inventory in ansible/inventories/examples/single-node/hosts.ini
- [X] T007 Verify ansible.cfg configuration at repository root (collections paths, roles path, inventory defaults)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core shared role and prerequisite validation that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T008 Define k3s-common role defaults in ansible/roles/k3s-common/defaults/main.yml (k3s_version pin, supported OS list, required ports)
- [X] T009 Implement prerequisite validation tasks in ansible/roles/k3s-common/tasks/prerequisites.yml (OS check, architecture check, systemd check, fail-fast on unsupported)
- [X] T010 Implement dependency installation tasks in ansible/roles/k3s-common/tasks/dependencies.yml (required packages, kernel modules, sysctl settings)
- [X] T011 Implement k3s-common main task file in ansible/roles/k3s-common/tasks/main.yml (orchestrate prerequisites and dependencies)

**Checkpoint**: Foundation ready — user story implementation can now begin in parallel

---

## Phase 3: User Story 1 — Provision New HA k3s Cluster (Priority: P1) 🎯 MVP

**Goal**: Provision a new HA embedded-etcd k3s cluster and optional add-ons, with kube-vip installed as a DaemonSet for stable control-plane and service endpoints.

**Independent Test**: Run ansible/playbooks/cluster-core.yml against the HA example inventory, verify cluster health and kube-vip DaemonSet readiness, then run ansible/playbooks/cluster-addons.yml with enabled add-ons and verify component availability.

### Core Cluster Roles

- [X] T012 [P] [US1] Define k3s-server role defaults in ansible/roles/k3s-server/defaults/main.yml (version, token, cluster-init flags, embedded etcd settings)
- [X] T013 [P] [US1] Define k3s-agent role defaults in ansible/roles/k3s-agent/defaults/main.yml (version, token, server URL, labels, taints)
- [X] T014 [US1] Implement k3s server installation tasks in ansible/roles/k3s-server/tasks/install.yml (download, systemd unit, initial server bootstrap, join additional servers)
- [X] T015 [US1] Implement kubeconfig retrieval tasks in ansible/roles/k3s-server/tasks/kubeconfig.yml (fetch kubeconfig, rewrite server URL to VIP)
- [X] T016 [US1] Implement k3s-server main task file in ansible/roles/k3s-server/tasks/main.yml (orchestrate install + kubeconfig)
- [X] T017 [US1] Implement k3s agent installation tasks in ansible/roles/k3s-agent/tasks/install.yml (download, systemd unit, join cluster)
- [X] T018 [US1] Implement k3s-agent main task file in ansible/roles/k3s-agent/tasks/main.yml (orchestrate agent install)

### kube-vip Role (DaemonSet Mode)

- [X] T019 [P] [US1] Define kube-vip DaemonSet defaults in ansible/roles/kube-vip/defaults/main.yml (VIP address, interface, ARP mode, service LB range, deployment_mode: daemonset)
- [X] T020 [US1] Create kube-vip DaemonSet manifest template in ansible/roles/kube-vip/templates/kube-vip-daemonset.yaml.j2
- [X] T021 [P] [US1] Create kube-vip cloud-controller manifest template in ansible/roles/kube-vip/templates/kube-vip-cloud-controller.yaml.j2
- [X] T022 [US1] Implement kube-vip DaemonSet install tasks in ansible/roles/kube-vip/tasks/install.yml (RBAC, DaemonSet apply, cloud-controller for service LB)
- [X] T023 [US1] Implement kube-vip main task file in ansible/roles/kube-vip/tasks/main.yml
- [X] T024 [US1] Implement kube-vip handler for DaemonSet restart in ansible/roles/kube-vip/handlers/main.yml

### Core Cluster Playbook

- [X] T025 [US1] Implement cluster-core playbook in ansible/playbooks/cluster-core.yml (k3s-common → k3s-server → kube-vip → k3s-agent orchestration)

### Add-on Roles: cert-manager

- [X] T026 [P] [US1] Define cert-manager role defaults in ansible/roles/cert-manager/defaults/main.yml (enabled flag, email, dns_provider, issuer names)
- [X] T027 [P] [US1] Create DNS provider credentials secret template in ansible/roles/cert-manager/templates/dns-provider-secret.yaml.j2
- [X] T028 [P] [US1] Create staging ClusterIssuer template in ansible/roles/cert-manager/templates/clusterissuer-staging.yaml.j2
- [X] T029 [P] [US1] Create production ClusterIssuer template in ansible/roles/cert-manager/templates/clusterissuer-production.yaml.j2
- [X] T030 [US1] Implement cert-manager install tasks in ansible/roles/cert-manager/tasks/install.yml (Helm chart deploy, wait for readiness)
- [X] T031 [US1] Implement cert-manager main tasks in ansible/roles/cert-manager/tasks/main.yml (install + issuers + secrets)

### Add-on Roles: multus

- [X] T032 [P] [US1] Define multus role defaults in ansible/roles/multus/defaults/main.yml (enabled flag, vlan_networks list)
- [X] T033 [P] [US1] Create NetworkAttachmentDefinition template in ansible/roles/multus/templates/net-attach-def.yaml.j2
- [X] T034 [US1] Implement multus install and configuration tasks in ansible/roles/multus/tasks/main.yml (deploy multus, create NetworkAttachmentDefinitions from variables)

### Add-on Roles: Traefik

- [X] T035 [P] [US1] Define traefik role defaults in ansible/roles/traefik/defaults/main.yml (enabled flag, service type, entrypoints)
- [X] T036 [P] [US1] Create Traefik Helm values template in ansible/roles/traefik/templates/traefik-values.yaml.j2
- [X] T037 [US1] Implement Traefik install tasks in ansible/roles/traefik/tasks/main.yml (Helm chart deploy with values, wait for readiness)

### Add-on Roles: Rancher

- [X] T038 [P] [US1] Define rancher role defaults in ansible/roles/rancher/defaults/main.yml (enabled flag, hostname, ingress class, TLS source)
- [X] T039 [P] [US1] Create Rancher Helm values template in ansible/roles/rancher/templates/rancher-values.yaml.j2
- [X] T040 [US1] Implement Rancher install tasks in ansible/roles/rancher/tasks/main.yml (Helm chart deploy, wait for readiness, verify ingress reachable)

### Add-on Roles: rancher-monitoring

- [X] T041 [P] [US1] Define rancher-monitoring role defaults in ansible/roles/rancher-monitoring/defaults/main.yml (enabled flag, retention, scrape overrides)
- [X] T042 [P] [US1] Create rancher-monitoring Helm values template in ansible/roles/rancher-monitoring/templates/monitoring-values.yaml.j2
- [X] T043 [US1] Implement rancher-monitoring install tasks in ansible/roles/rancher-monitoring/tasks/main.yml (Helm chart deploy, verify Prometheus/Grafana readiness)

### Add-on Roles: Synology CSI (Optional)

- [X] T044 [P] [US1] Define synology-csi role defaults in ansible/roles/synology-csi/defaults/main.yml (enabled flag, endpoint, storage classes)
- [X] T045 [P] [US1] Create Synology CSI credentials secret template in ansible/roles/synology-csi/templates/synology-csi-secret.yaml.j2
- [X] T046 [P] [US1] Create StorageClass template in ansible/roles/synology-csi/templates/storageclass.yaml.j2
- [X] T047 [US1] Implement synology-csi install tasks in ansible/roles/synology-csi/tasks/main.yml (deploy CSI driver, create secret, create StorageClasses)

### Add-ons Playbook

- [X] T048 [US1] Implement cluster-addons playbook in ansible/playbooks/cluster-addons.yml (cert-manager → traefik → rancher → rancher-monitoring → multus → synology-csi orchestration, each gated by enabled flag)

**Checkpoint**: At this point, User Story 1 should be fully functional — a new HA cluster can be provisioned end-to-end with all add-ons via `cluster-core.yml` + `cluster-addons.yml`.

---

## Phase 4: User Story 2 — Update Existing Cluster Configuration (Priority: P2)

**Goal**: Enable safe, idempotent re-runs of both playbooks to converge an existing cluster to updated desired state without recreation or disruption.

**Independent Test**: Change cert-manager issuer email, Traefik entrypoints, or kube-vip service LB range in variables, re-run the appropriate playbook, and verify only targeted resources change while the cluster remains healthy.

### Implementation for User Story 2

- [X] T049 [US2] Add idempotent change-detection guards to ansible/roles/k3s-server/tasks/install.yml (skip re-install when version matches, notify handlers on config change only)
- [X] T050 [P] [US2] Add idempotent convergence logic to ansible/roles/kube-vip/tasks/install.yml (template diff detection, notify handler on DaemonSet manifest change)
- [X] T051 [P] [US2] Add idempotent convergence logic to ansible/roles/cert-manager/tasks/install.yml (Helm upgrade with changed values only, issuer update on variable change)
- [X] T052 [P] [US2] Add idempotent convergence logic to ansible/roles/traefik/tasks/main.yml (Helm upgrade idempotence)
- [X] T053 [P] [US2] Add idempotent convergence logic to ansible/roles/rancher/tasks/main.yml (Helm upgrade idempotence)
- [X] T054 [P] [US2] Add idempotent convergence logic to ansible/roles/rancher-monitoring/tasks/main.yml (Helm upgrade idempotence)
- [X] T055 [P] [US2] Add idempotent convergence logic to ansible/roles/multus/tasks/main.yml (NetworkAttachmentDefinition update without recreation)
- [X] T056 [P] [US2] Add idempotent convergence logic to ansible/roles/synology-csi/tasks/main.yml (StorageClass and secret update without recreation)
- [X] T057 [US2] Ensure ansible/roles/k3s-agent/tasks/install.yml handles agent config updates idempotently (service restart only on change)

**Checkpoint**: At this point, User Story 2 should be fully functional — re-running playbooks with changed variables updates only the affected resources.

---

## Phase 5: User Story 3 — Manage Control-Plane and Worker Nodes (Priority: P3)

**Goal**: Enable adding and removing control-plane and worker nodes via inventory changes while preserving cluster health and etcd quorum.

**Independent Test**: Start from a working 3-CP cluster, add a worker via inventory, run scale-nodes.yml and verify it joins; then mark a worker for removal, re-run and verify it is drained and detached.

### Implementation for User Story 3

- [X] T058 [US3] Implement node join logic for new servers in ansible/playbooks/scale-nodes.yml (detect new k3s_servers entries, run k3s-common + k3s-server roles on them)
- [X] T059 [US3] Implement node join logic for new agents in ansible/playbooks/scale-nodes.yml (detect new k3s_agents entries, run k3s-common + k3s-agent roles on them)
- [X] T060 [US3] Implement node drain and removal logic in ansible/playbooks/scale-nodes.yml (cordon, drain, stop k3s service, remove node from cluster)
- [X] T061 [US3] Add etcd quorum safety check before control-plane node removal in ansible/playbooks/scale-nodes.yml (assert remaining servers maintain quorum)
- [X] T062 [P] [US3] Add node removal variable/marker pattern documentation in ansible/inventories/examples/ha-cluster/hosts.ini (commented example showing node_state=absent)

**Checkpoint**: All user stories should now be independently functional — provision, update, and scale operations all work.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Upgrade workflow, documentation, linting compliance, and smoke tests

- [X] T063 Implement k3s upgrade playbook in ansible/playbooks/upgrade-k3s.yml (rolling server upgrade → rolling agent upgrade, version variable override)
- [X] T064 [P] Create smoke test playbook in tests/ansible/smoke/smoke.yml (verify nodes ready, kube-vip DaemonSet running, API reachable via VIP)
- [X] T065 [P] Create idempotence test playbook in tests/ansible/smoke/idempotence-test.yml (run cluster-core twice, assert no changed tasks on second run)
- [X] T066 [P] Create scale test playbook in tests/ansible/smoke/scale-test.yml (add/remove a node, verify cluster health)
- [X] T067 [P] Create upgrade test playbook in tests/ansible/smoke/upgrade-test.yml (change k3s_version, run upgrade, verify new version)
- [X] T068 [P] Write architecture overview documentation in docs/ansible-k3s-baseline.md
- [X] T069 [P] Write repository layout documentation in docs/ansible-structure.md
- [X] T070 [P] Write role-level README for k3s-common in ansible/roles/k3s-common/README.md
- [X] T071 [P] Write role-level README for k3s-server in ansible/roles/k3s-server/README.md
- [X] T072 [P] Write role-level README for k3s-agent in ansible/roles/k3s-agent/README.md
- [X] T073 [P] Write role-level README for kube-vip in ansible/roles/kube-vip/README.md
- [X] T074 [P] Write role-level README for cert-manager in ansible/roles/cert-manager/README.md
- [X] T075 Validate all playbooks and roles pass ansible-lint with no errors
- [X] T076 Run quickstart.md validation (verify documented commands match actual playbook paths and variable names)
- [X] T077 [P] Create Synology CSI PVC validation smoke test in tests/ansible/smoke/synology-pvc-test.yml (create PVC against Synology StorageClass, bind, write data, verify availability — validates SC-005)
- [X] T078 [P] Create DNS-01 provider switch validation smoke test in tests/ansible/smoke/dns-provider-switch-test.yml (change dns_provider variable, re-run cert-manager role, verify issuer renewal with new provider — validates SC-007)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2 (Phase 4)**: Depends on User Story 1 (needs roles to exist before adding idempotent guards)
- **User Story 3 (Phase 5)**: Depends on User Story 1 (requires k3s-server and k3s-agent roles); can run in parallel with US2
- **Polish (Final Phase)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **User Story 2 (P2)**: Depends on US1 role implementations existing (adds convergence logic to those roles)
- **User Story 3 (P3)**: Depends on US1 completion (requires k3s-server and k3s-agent roles) — independent of US2; can run in parallel with US2

### Within Each User Story

- Role defaults before role tasks
- Role tasks before playbook orchestration
- Templates before tasks that reference them
- Core cluster roles before add-on roles (within US1)
- cluster-core.yml before cluster-addons.yml

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002–T006)
- Within US1: all role defaults (T012, T013, T019, T026, T032, T035, T038, T041, T044) can run in parallel
- Within US1: all templates for a given role marked [P] can run in parallel
- Within US2: all idempotent convergence tasks (T050–T056) can run in parallel (different role files)
- All Polish phase documentation tasks (T068–T074) can run in parallel
- All smoke test playbooks (T064–T067) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all role defaults in parallel:
Task: T012 "Define k3s-server role defaults in ansible/roles/k3s-server/defaults/main.yml"
Task: T013 "Define k3s-agent role defaults in ansible/roles/k3s-agent/defaults/main.yml"
Task: T019 "Define kube-vip DaemonSet defaults in ansible/roles/kube-vip/defaults/main.yml"
Task: T026 "Define cert-manager role defaults in ansible/roles/cert-manager/defaults/main.yml"
Task: T032 "Define multus role defaults in ansible/roles/multus/defaults/main.yml"
Task: T035 "Define traefik role defaults in ansible/roles/traefik/defaults/main.yml"
Task: T038 "Define rancher role defaults in ansible/roles/rancher/defaults/main.yml"
Task: T041 "Define rancher-monitoring role defaults in ansible/roles/rancher-monitoring/defaults/main.yml"
Task: T044 "Define synology-csi role defaults in ansible/roles/synology-csi/defaults/main.yml"

# Then launch templates in parallel per role:
Task: T020 "Create kube-vip DaemonSet manifest template"
Task: T021 "Create kube-vip cloud-controller manifest template"
Task: T027 "Create DNS provider credentials secret template"
Task: T028 "Create staging ClusterIssuer template"
Task: T029 "Create production ClusterIssuer template"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run cluster-core.yml + cluster-addons.yml against example inventory
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test cluster provisioning independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test re-run convergence independently → Deploy/Demo
4. Add User Story 3 → Test node scaling independently → Deploy/Demo
5. Add Polish → Upgrade workflow, docs, lint compliance
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core cluster roles → add-on roles → playbooks)
   - Developer B: User Story 3 (scale-nodes logic — can start once k3s-server/agent roles exist)
3. After US1 complete:
   - Developer B: User Story 2 (add idempotent guards to existing roles)
4. All: Polish phase (docs, tests, lint)

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- kube-vip MUST be deployed as DaemonSet per planning directive (docs/ai-prompts/plan.md)
- Secrets (tokens, DNS credentials, Synology credentials) must NEVER be committed — use Ansible Vault or external secret management
- Commit after each task or logical group
