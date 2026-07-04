---
description: "Task list for kubernetes.core.k8s module standardization refactor"
---

# Tasks: kubernetes.core.k8s Module Standardization

**Input**: Design documents from `/specs/004-k8s-module-refactor/`

**References**: [spec.md](spec.md) | [plan.md](plan.md) | [research.md](research.md) | [data-model.md](data-model.md) | [quickstart.md](quickstart.md)

**No tests requested** — this refactor spec does not include test tasks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label — [US1], [US2], [US3]
- Exact file paths are included in all descriptions

---

## Phase 1: Setup

**Purpose**: Verify collection prerequisites are in place before beginning role migrations.

- [ ] T001 Verify `kubernetes.core >= 2.4.0` and `community.kubernetes >= 3.0.0` are declared in `ansible/requirements.yml` (per R-001; no change expected — confirm and proceed)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No blocking prerequisites exist beyond Phase 1 — the `kubernetes.core` collection is already installed and all migration patterns are resolved in `research.md` (R-002 through R-010). Proceed directly to User Story phases after T001.

**⚠️ CRITICAL**: Confirm T001 before beginning any User Story work.

**Checkpoint**: Collection verified — user story implementation can begin.

---

## Phase 3: User Story 1 — Replace kubectl Resource Operations (Priority: P1) 🎯 MVP

**Goal**: All `kubectl apply`, `kubectl create namespace`, and `kubectl scale` invocations in in-scope roles are replaced with `kubernetes.core.k8s`. Temp-file write/cleanup tasks that existed only to support `kubectl apply -f /tmp/...` are removed.

**Independent Test**: Run `grep -rn "kubectl" ansible/roles/cert-manager/tasks/ ansible/roles/multus/tasks/ ansible/roles/kube-vip/tasks/ ansible/roles/rancher/tasks/` — zero resource-mutation matches. Re-run each refactored role; idempotence on second run with zero `changed` tasks (SC-001).

### Implementation for User Story 1

- [ ] T002 [P] [US1] Replace all kubectl resource operations in `ansible/roles/cert-manager/tasks/install.yml`: (a) fetch CRDs manifest via `ansible.builtin.uri` + apply with `kubernetes.core.k8s` loop using `from_yaml_all` (R-002); (b) replace `kubectl create namespace cert-manager` with `kubernetes.core.k8s` Namespace `state: present` (R-007); (c) fetch cert-manager deployment manifest via `ansible.builtin.uri` + apply with `kubernetes.core.k8s` loop using `from_yaml_all` (R-002); (d) replace DNS credentials secret `kubectl apply` with `kubernetes.core.k8s` using `lookup('template') | from_yaml`, preserving `no_log: true` (R-008); (e) replace staging and production ClusterIssuer `kubectl apply` with `kubernetes.core.k8s` using `lookup('template') | from_yaml` (R-003); (f) replace three `kubectl scale deployment` tasks with `kubernetes.core.k8s` partial definition patches on `spec.replicas` (R-010); (g) remove all five `/tmp/` file write tasks and their corresponding cleanup tasks

- [ ] T003 [P] [US1] Replace all kubectl resource operations in `ansible/roles/multus/tasks/install.yml`: (a) replace `kubectl apply -f - stdin: multus-daemonset-thick.yml.j2` with `kubernetes.core.k8s` loop using `lookup('template') | from_yaml_all | list` for multi-doc manifest (R-003); (b) replace `kubectl apply -f - stdin: network-attachment-definition.yaml.j2` (looped over `multus_vlan_networks`) with `kubernetes.core.k8s` using `lookup('template') | from_yaml` in the same loop (R-009); (c) replace `kubectl apply -f - stdin: multus-dhcp-daemon.yaml.j2` with `kubernetes.core.k8s` using `lookup('template') | from_yaml` (R-003)

- [ ] T004 [P] [US1] Replace all kubectl resource-apply operations in `ansible/roles/kube-vip/tasks/install.yml`: (a) replace `kubectl apply -f /tmp/kube-vip-daemonset.yaml` with `kubernetes.core.k8s` using `lookup('template', 'kube-vip-daemonset.yaml.j2') | from_yaml` with `host: https://127.0.0.1:6443` and `validate_certs: false` (R-004); (b) replace `kubectl apply -f /tmp/kube-vip-cloud-controller.yaml` with `kubernetes.core.k8s` using `lookup('template') | from_yaml` with same host/validate_certs params (R-004); (c) replace `kubectl apply -f /tmp/kube-vip-configmap.yaml` with `kubernetes.core.k8s` using `lookup('template') | from_yaml` with same params (R-004); (d) remove all six `/tmp/` file write tasks and their corresponding cleanup tasks; (e) do NOT modify health-probe or diagnostic tasks — these must remain as `ansible.builtin.command` per FR-007

- [ ] T005 [P] [US1] Replace `kubectl create namespace cattle-system` in `ansible/roles/rancher/tasks/install.yml` with `kubernetes.core.k8s` `kind: Namespace` `state: present` (R-007); remove the `changed_when`/`failed_when` AlreadyExists guard — `kubernetes.core.k8s` is natively idempotent

**Checkpoint**: At this point, all resource-mutation kubectl calls are eliminated from cert-manager, multus, kube-vip, and rancher roles. Validate with Validation 1 grep from `quickstart.md` before proceeding to Phase 4.

---

## Phase 4: User Story 2 — Replace kubectl Wait/Rollout Patterns (Priority: P2)

**Goal**: All `kubectl wait --for=condition=available` and `kubectl rollout status` calls are replaced with `kubernetes.core.k8s_info` polling loops (`retries` + `delay` + `until`).

**Independent Test**: Deploy the cert-manager role and confirm no `kubectl wait` or `kubectl rollout` tasks are present; readiness is verified via `kubernetes.core.k8s_info` polling (quickstart.md Validation 1).

### Implementation for User Story 2

- [ ] T006 [P] [US2] Replace `kubectl wait --for=condition=available deployment --all -n cert-manager` in `ansible/roles/cert-manager/tasks/install.yml` with three explicit `kubernetes.core.k8s_info` polling tasks — one each for `cert-manager`, `cert-manager-webhook`, and `cert-manager-cainjector` deployments — checking `status.availableReplicas >= 1` with `retries: 30` and `delay: 10` (R-005)

- [ ] T007 [P] [US2] Replace both `kubectl rollout status daemonset/...` tasks in `ansible/roles/multus/tasks/install.yml` with `kubernetes.core.k8s_info` polling loops: (a) `kube-multus-ds` DaemonSet readiness checking `status.numberReady == status.desiredNumberScheduled` with `retries: 18` and `delay: 10`; (b) `multus-dhcp-daemon` DaemonSet readiness with same pattern (R-006)

- [ ] T008 [P] [US2] Replace `kubectl wait --for=condition=available deployment traefik -n kube-system` in `ansible/roles/traefik/tasks/configure.yml` with `kubernetes.core.k8s_info` polling checking `status.availableReplicas >= 1` with `retries: 30` and `delay: 10` (R-005)

- [ ] T009 [P] [US2] Replace `kubectl rollout status daemonset/kube-vip -n kube-system` in `ansible/roles/kube-vip/tasks/install.yml` with `kubernetes.core.k8s_info` polling checking `status.numberReady == status.desiredNumberScheduled` with `host: https://127.0.0.1:6443`, `validate_certs: false`, `retries: 30`, and `delay: 10` (R-006)

**Checkpoint**: All wait and rollout-status kubectl calls are eliminated. Validate with Validation 1 grep from `quickstart.md` confirming zero `kubectl wait` and `kubectl rollout` invocations in refactored roles.

---

## Phase 5: User Story 3 — Verify Exempt Operations Unchanged (Priority: P3)

**Goal**: Confirm that kube-vip bootstrap health probes, Helm operations across all roles, and k3s-common diagnostic kubectl calls remain as `ansible.builtin.command`/`ansible.builtin.shell` tasks — no accidental migration occurred.

**Independent Test**: Bootstrap a cluster from scratch; confirm `/readyz` probes succeed, Helm installs complete, and k3s service tasks execute correctly (quickstart.md Validation 4).

### Implementation for User Story 3

- [ ] T010 [P] [US3] Review `ansible/roles/kube-vip/tasks/install.yml` and confirm the following tasks are unchanged as `ansible.builtin.command`: (a) `Wait for Kubernetes API readiness endpoint` (`kubectl ... get --raw=/readyz`); (b) `Wait for Kubernetes API discovery to become available` (`kubectl ... api-resources`); (c) `Collect k3s service status for diagnostics` (`systemctl status k3s`); (d) `Collect recent k3s journal logs` (`journalctl -u k3s`); (e) `Collect /readyz verbose output` — cross-reference against data-model.md Exemption Registry

- [ ] T011 [P] [US3] Review and confirm Helm shell tasks are unchanged in: (a) `ansible/roles/traefik/tasks/configure.yml` — `Deploy Traefik via Helm` (`ansible.builtin.shell: helm upgrade --install ...`); (b) `ansible/roles/rancher/tasks/install.yml` — `Install Rancher via Helm`; (c) `ansible/roles/rancher-monitoring/tasks/install.yml` — `Install rancher-monitoring via Helm`

**Checkpoint**: Exempt operations verified unchanged. User Story 3 complete. Proceed to Phase 6 (rancher-monitoring) or directly to Phase 7 if rancher-monitoring is deferred.

---

## Phase 6: rancher-monitoring — US1 + US2 Lower Priority (Conditional)

**Condition**: Begin only after Phases 3 and 4 are validated passing (idempotence confirmed for primary roles).

**Goal**: Apply the same namespace and wait migrations to `rancher-monitoring` to complete full-scope coverage per spec.md (conditional DoD).

**Independent Test**: Re-run rancher-monitoring role; namespace creation reports `ok` (not AlreadyExists failure); readiness wait uses `kubernetes.core.k8s_info` polling.

- [ ] T012 [US1] Replace `kubectl create namespace cattle-monitoring-system` in `ansible/roles/rancher-monitoring/tasks/install.yml` with `kubernetes.core.k8s` `kind: Namespace` `state: present`; remove AlreadyExists guard (R-007)

- [ ] T013 [US2] Replace `kubectl wait --for=condition=available deployment -l app.kubernetes.io/name=grafana -n cattle-monitoring-system` in `ansible/roles/rancher-monitoring/tasks/install.yml` with `kubernetes.core.k8s_info` polling using `label_selectors: ["app.kubernetes.io/name=grafana"]`, checking `status.availableReplicas >= 1` with `retries: 20` and `delay: 30` to match the original 600s timeout budget (R-005)

**Checkpoint**: rancher-monitoring fully migrated. All six in-scope roles now use `kubernetes.core.k8s`/`k8s_info` exclusively for resource operations.

---

## Phase 7: Polish & Validation

**Purpose**: Static verification, lint, and smoke test validation to confirm all success criteria are met.

- [ ] T014 [P] Run `ansible-lint` on all refactored roles and confirm exit code 0: `ansible-lint ansible/roles/cert-manager/ ansible/roles/multus/ ansible/roles/traefik/ ansible/roles/kube-vip/ ansible/roles/rancher/ ansible/roles/rancher-monitoring/` (quickstart.md Validation 2)

- [ ] T015 [P] Run static grep validation per quickstart.md Validation 1 — confirm zero `kubectl apply`, `kubectl create`, `kubectl delete`, `kubectl patch`, `kubectl scale`, `kubectl wait`, and `kubectl rollout` invocations in refactored role task files (SC-001, SC-002); permitted matches: `kubectl --raw=/readyz`, `kubectl ... api-resources` in `kube-vip/tasks/install.yml` only

- [ ] T016 Run full clean deployment (quickstart.md Validation 4) and idempotence smoke test (quickstart.md Validation 3: `tests/ansible/smoke/idempotence-test.yml`) against test cluster; confirm `failed=0` on clean deploy and `changed=0` for all refactored roles on second run (SC-003, SC-004, SC-005)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on T001 — no additional work; unblocks Phases 3–5
- **Phase 3 (US1)**: Depends on Phase 2 checkpoint; all US1 tasks [P] can run in parallel across roles
- **Phase 4 (US2)**: Depends on Phase 2; can proceed in parallel with Phase 3 since edits are to different sections of the same files — but validating Phase 3 first is recommended before beginning Phase 4
- **Phase 5 (US3)**: Depends on Phase 2; can proceed in parallel with Phases 3 and 4 (verification only)
- **Phase 6 (rancher-monitoring)**: Depends on Phases 3 and 4 passing validation
- **Phase 7 (Polish)**: Depends on all desired phases complete; T014/T015 [P] can run in parallel

### User Story Dependencies

- **US1 (Phase 3)**: No dependency on other stories — can start after T001
- **US2 (Phase 4)**: No hard dependency on US1; edits different task sections — but idempotence is easier to verify incrementally after US1 is done
- **US3 (Phase 5)**: No dependency — verification only; can run any time
- **rancher-monitoring (Phase 6)**: Depends on US1 + US2 validation

### Parallel Opportunities

All US1 role tasks (T002–T005) are in different files and can be worked in parallel:

```
T002  ansible/roles/cert-manager/tasks/install.yml   ──┐
T003  ansible/roles/multus/tasks/install.yml          ──┤ all parallel
T004  ansible/roles/kube-vip/tasks/install.yml        ──┤ (different files)
T005  ansible/roles/rancher/tasks/install.yml         ──┘
```

All US2 role tasks (T006–T009) are also in different files and can be worked in parallel:

```
T006  ansible/roles/cert-manager/tasks/install.yml   ──┐
T007  ansible/roles/multus/tasks/install.yml          ──┤ all parallel
T008  ansible/roles/traefik/tasks/configure.yml       ──┤ (different files)
T009  ansible/roles/kube-vip/tasks/install.yml        ──┘
```

Polish tasks T014 and T015 can run in parallel (grep and lint are independent).

---

## Implementation Strategy

### MVP First (US1 Only — Phase 3)

1. Complete Phase 1: T001 (verify requirements.yml)
2. Complete Phase 3: T002–T005 (replace all resource-mutation kubectl calls)
3. **STOP and VALIDATE**: Run Validation 1 grep from `quickstart.md` — zero resource-mutation kubectl matches
4. Run second-pass idempotence check on one role (e.g., cert-manager)
5. If passing: proceed to Phase 4 (US2) and Phase 5 (US3)
6. After all phases: complete Phase 7 validation

### Per-Task Implementation Reference

Each task maps to canonical migration patterns in `research.md`:

| Pattern | Research | Tasks |
|---------|----------|-------|
| P-APPLY-REMOTE (`uri` + `from_yaml_all`) | R-002 | T002 (a, c) |
| P-APPLY-TEMPLATE (`lookup('template')` + `from_yaml`) | R-003 | T002 (d, e), T003, T004 |
| P-APPLY-STDIN (`lookup('template')` + `from_yaml`) | R-003 | T003 |
| P-NAMESPACE (`state: present`) | R-007 | T002 (b), T005, T012 |
| P-WAIT-DEPLOY (`k8s_info` Deployment poll) | R-005 | T006, T008, T013 |
| P-WAIT-DS (`k8s_info` DaemonSet poll) | R-006 | T007, T009 |
| P-SCALE (spec.replicas patch) | R-010 | T002 (f) |
| kube-vip host/validate_certs | R-004 | T004, T009 |
| no_log preservation | R-008 | T002 (d) |
| NAD loop | R-009 | T003 (b) |
