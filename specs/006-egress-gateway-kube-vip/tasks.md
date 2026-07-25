---
description: "Task list for Egress Gateway and Kube-VIP Enhancements"
---

# Tasks: Egress Gateway and Kube-VIP Enhancements

**Input**: Design documents from `/specs/006-egress-gateway-kube-vip/`

**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ansible-variable-contracts.md ✅

**Tests**: Included — explicitly required by spec (FR-013) and ai-prompts/plan-egress-gateway-and-kube-vip-updates.md.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no upstream dependencies)
- **[Story]**: User story label (US1–US4)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold new role structure and shared prerequisites before any user story begins.

- [ ] T001 Create `ansible/roles/cilium/` directory structure: `defaults/main.yml`, `tasks/main.yml`, `tasks/install.yml`, `README.md`
- [ ] T002 [P] Add all new `kube-vip` role variables with `false` defaults to `ansible/roles/kube-vip/defaults/main.yml` (egress, election, DHCP variables per contracts/ansible-variable-contracts.md)
- [ ] T003 [P] Add new `cilium` role variables with defaults to `ansible/roles/cilium/defaults/main.yml` (`cilium_enabled`, `cilium_version`, `cilium_namespace`, `cilium_helm_repo`, `cilium_egress_gateway_enabled`)
- [ ] T004 [P] Add all new kube-vip and cilium variable defaults to `ansible/group_vars/all.yml`
- [ ] T005 Create `ansible/roles/kube-vip/tasks/validate.yml` — pre-flight assertion task file (empty placeholder; logic added per story)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Validation scaffolding and Cilium role entry point. Must complete before US1/US3.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T006 Implement `ansible/roles/kube-vip/tasks/validate.yml` — assert `kube_vip_egress_ip` is non-empty when `kube_vip_egress_enabled: true`; assert Cilium is active CNI when `kube_vip_egress_enabled: true` (FR-003b); assert DHCP/static range mutual exclusion (FR-007)
- [ ] T007 [P] Add `validate.yml` include to `ansible/roles/kube-vip/tasks/main.yml` as first task (before any conditionally-executed feature tasks)
- [ ] T008 Implement `ansible/roles/cilium/tasks/main.yml` — entry point with `cilium_enabled` guard and include of `install.yml`
- [ ] T009 Implement `ansible/roles/cilium/tasks/install.yml` — Helm install of Cilium (`cilium_version` pinned, `cilium_namespace`, `cilium_egress_gateway_enabled` Helm value); wait for DaemonSet ready using `kubernetes.core.k8s_info`

**Checkpoint**: Validation and Cilium role skeleton complete — user story phases can proceed.

---

## Phase 3: User Story 4 — Consolidated RBAC (Priority: P2) ⬅ Implement First

**Goal**: Merge kube-vip and kube-vip-cloud-controller ClusterRoles into single `kube-vip` ClusterRole; bind both service accounts to it.

**Why first**: RBAC is a prerequisite for all kube-vip pod operations. Later stories depend on correct RBAC being in place.

**Independent Test**: Apply kube-vip role; verify single ClusterRole `kube-vip` exists with all required API groups/verbs; verify two ClusterRoleBindings both reference `kube-vip`; verify zero RBAC-denied log lines in kube-vip and cloud-controller pods. (See quickstart.md Scenario 1.)

### Tests for User Story 4

- [ ] T010 [P] [US4] Add RBAC smoke test block to `tests/ansible/smoke/egress-gateway-test.yml` — assert single ClusterRole `kube-vip` exists; assert `kube-vip` and `kube-vip-cloud-controller` ClusterRoleBindings both reference `roleRef.name: kube-vip`; assert zero `forbidden|rbac|denied` lines in pod logs

### Implementation for User Story 4

- [ ] T011 [US4] Create `ansible/roles/kube-vip/templates/kube-vip-rbac.yaml.j2` — dedicated RBAC template containing: ServiceAccount `kube-vip` (kube-system), ServiceAccount `kube-vip-cloud-controller` (kube-system), single consolidated ClusterRole `kube-vip` with union of all required rules (per data-model.md §4: services, services/status, nodes, endpoints, configmaps, events, endpointslices, leases — all verbs; verify `pods` verb requirement against kube-vip v1.1.2), ClusterRoleBinding `kube-vip` → SA `kube-vip`, ClusterRoleBinding `kube-vip-cloud-controller` → SA `kube-vip-cloud-controller`; all resources separated by `---`
- [ ] T012 [US4] Remove ClusterRole, ClusterRoleBinding, and ServiceAccount definitions from `ansible/roles/kube-vip/templates/kube-vip-daemonset.yaml.j2` and `ansible/roles/kube-vip/templates/kube-vip-cloud-controller.yaml.j2` — retain only Deployment/DaemonSet manifest content in each
- [ ] T013 [US4] Add `kubernetes.core.k8s` task in `ansible/roles/kube-vip/tasks/install.yml` to apply `kube-vip-rbac.yaml.j2` with `state: present` (idempotent overwrite per FR-008/FR-009); ensure RBAC task runs before DaemonSet and cloud-controller tasks
- [ ] T014 [P] [US4] Update `ansible/roles/kube-vip/README.md` — document consolidated RBAC template (`kube-vip-rbac.yaml.j2`), single ClusterRole design, both ClusterRoleBindings, and all included ServiceAccounts

---

## Phase 4: User Story 2 — Service Election for HA (Priority: P2)

**Goal**: Enable per-service leader election (`svc_election`) in kube-vip DaemonSet, auto-enabled when egress gateway is enabled.

**Independent Test**: On HA cluster (≥2 control-plane nodes), enable service election, create a LoadBalancer service, verify only one node owns the VIP; cordon the leader; verify VIP migrates. (See quickstart.md Scenario 2.)

### Tests for User Story 2

- [ ] T015 [P] [US2] Add service election smoke test block to `tests/ansible/smoke/egress-gateway-test.yml` — assert `svc_election` env var present in kube-vip DaemonSet pod spec; assert only one node holds each service VIP lease (via `kubectl get leases -n kube-system`)

### Implementation for User Story 2

- [ ] T016 [US2] Update `ansible/roles/kube-vip/templates/kube-vip-daemonset.yaml.j2` — add `svc_election` env var conditioned on `kube_vip_svc_election_enabled | bool`; add `vip_leaseduration`, `vip_renewdeadline`, `vip_retryperiod` env vars with defaults from role variables
- [ ] T017 [US2] Add `kube_vip_svc_election_enabled`, `vip_leaseduration`, `vip_renewdeadline`, `vip_retryperiod` variables to `ansible/roles/kube-vip/defaults/main.yml` (if not already added in T002)
- [ ] T018 [P] [US2] Update `ansible/roles/kube-vip/README.md` — document `kube_vip_svc_election_enabled` variable, lease timing variables, and auto-enable behavior when egress gateway is enabled

---

## Phase 5: User Story 1 — Load-Balanced Egress Gateway (Priority: P1) 🎯 MVP

**Goal**: Provision egress VIP via kube-vip LoadBalancer Service + `CiliumEgressGatewayPolicy` so all pod outbound traffic exits through a stable cluster IP.

**Independent Test**: Deploy egress gateway config; from a pod inside the cluster make outbound HTTP request to external echo service; verify observed source IP matches `kube_vip_egress_ip`, not a node IP. (See quickstart.md Scenario 4.)

### Tests for User Story 1

- [ ] T019 [US1] Create `tests/ansible/smoke/egress-gateway-test.yml` — full smoke test playbook: assert egress LoadBalancer Service exists in `kube_vip_egress_namespace` with `loadBalancerIP` matching `kube_vip_egress_ip`; assert `CiliumEgressGatewayPolicy` exists; launch test pod and verify outbound source IP equals egress VIP via external echo endpoint (FR-013, SC-001)

### Implementation for User Story 1

- [ ] T020 [US1] Create `ansible/roles/kube-vip/templates/kube-vip-egress-service.yaml.j2` — LoadBalancer Service with `loadBalancerIP: {{ kube_vip_egress_ip }}`, no `kube-vip.io/egress-internal` annotation, no `externalTrafficPolicy: Local` (per research.md Decision 1)
- [ ] T021 [US1] Create `ansible/roles/kube-vip/templates/kube-vip-egress-policy.yaml.j2` — `CiliumEgressGatewayPolicy` CR with `egressGateway.egressIP: {{ kube_vip_egress_ip }}`, `egressGateway.nodeSelector: {{ kube_vip_egress_gateway_node_selector }}`, `egressGateway.interface: {{ kube_vip_egress_gateway_interface }}`, `podSelector: {{ kube_vip_egress_pod_selector }}`, `namespaceSelector: {{ kube_vip_egress_namespace_selector }}`
- [ ] T022 [US1] Add egress gateway tasks to `ansible/roles/kube-vip/tasks/install.yml` — `kubernetes.core.k8s` with `state: present` for egress Service and CiliumEgressGatewayPolicy, both gated on `kube_vip_egress_enabled | bool`; force `kube_vip_svc_election_enabled: true` when egress enabled (set_fact)
- [ ] T023 [US1] Add `cilium_egress_gateway_enabled: true` auto-set logic in `ansible/roles/cilium/tasks/install.yml` when `kube_vip_egress_enabled: true` (set_fact before Helm install)
- [ ] T024 [P] [US1] Add egress gateway variable defaults to `ansible/roles/kube-vip/defaults/main.yml`: `kube_vip_egress_enabled`, `kube_vip_egress_ip`, `kube_vip_egress_hostname`, `kube_vip_egress_namespace`, `kube_vip_egress_policy_name`, `kube_vip_egress_pod_selector`, `kube_vip_egress_namespace_selector`, `kube_vip_egress_gateway_node_selector`, `kube_vip_egress_gateway_interface` (if not already added in T002)
- [ ] T024a [US1] Add failover test block to `tests/ansible/smoke/egress-gateway-test.yml` — cordon/drain the node currently holding the `kube_vip_egress_ip` lease, assert egress source IP resumes matching `kube_vip_egress_ip` within `vip_leaseduration` seconds (FR-003, SC-002)
- [ ] T025 [P] [US1] Update `docs/ansible-k3s-baseline.md` — remove "No Calico/Cilium" non-goal statement; add Cilium CNI section documenting egress gateway capability, `--flannel-backend=none`, `--disable-network-policy` k3s flags (FR-012)
- [ ] T026 [P] [US1] Update `ansible/roles/cilium/README.md` — document k3s flags required, Flannel migration note, `cilium_version` pinning requirement, and auto-enable behavior with egress gateway
- [ ] T027 [P] [US1] Update `ansible/roles/kube-vip/README.md` — document all egress gateway variables, `kube_vip_egress_gateway_node_selector` CONSTRAINT (must target subset of control-plane nodes where kube-vip DaemonSet runs), and failover behavior
- [ ] T027a [P] [US1] Update `docs/ansible-structure.md` — (a) replace Flannel port entries (`8472/udp`, `51820/udp`, `51821/udp`) in Network Requirements with Cilium equivalents (`8472/udp` VXLAN or `4240/tcp` health, `4244/tcp` Hubble) annotated as CNI-dependent; (b) update Non-Goals to replace "Custom CNI plugins beyond Flannel" with a note that Cilium is the supported CNI when egress gateway is enabled; (c) add a new **CNI Selection** subsection under Variable Structure documenting: this decision must be made at initial cluster deployment — Flannel-to-Cilium migration on a live cluster requires rolling k3s-server restarts and Flannel artifact cleanup; recommend Cilium (`cilium_enabled: true`) for any cluster intended to support egress or ingress gateway; document the deciding factors (stable predictable egress IP, `CiliumEgressGatewayPolicy` pod-level traffic steering, HA failover via kube-vip svc_election) vs Flannel (simpler, no egress gateway capability); note Flannel remains the default (`cilium_enabled: false`) for clusters that do not require egress gateway

---

## Phase 6: User Story 3 — DHCP for Kube-VIP Load Balancers (Priority: P3)

**Goal**: Enable DHCP-based IP assignment for LoadBalancer services when static IP range management is impractical.

**Independent Test**: Enable DHCP mode, create LoadBalancer service with `loadBalancerIP: 0.0.0.0`, verify service receives IP via DHCP from network infrastructure. (See quickstart.md Scenario 3.)

### Tests for User Story 3

- [ ] T028 [P] [US3] Add DHCP smoke test block to `tests/ansible/smoke/egress-gateway-test.yml` — assert `kube_vip_lb_dhcp_enabled` and non-empty `kube_vip_lb_ip_range` combination triggers playbook failure with expected error message; assert DHCP-only config produces valid ConfigMap (omits `range-global` key)

### Implementation for User Story 3

- [ ] T029 [US3] Verify `ansible/roles/kube-vip/tasks/validate.yml` assertion from T006 covers FR-007 mutual exclusion (`kube_vip_lb_dhcp_enabled: true` AND non-empty `kube_vip_lb_ip_range`); no new assertion needed — proceed to T030 configmap conditional
- [ ] T030 [US3] Update `ansible/roles/kube-vip/templates/kube-vip-configmap.yaml.j2` — add conditional: omit `range-global` key when `kube_vip_lb_dhcp_enabled: true`; keep existing `range-global: {{ kube_vip_lb_ip_range }}` when DHCP disabled
- [ ] T031 [P] [US3] Update `ansible/roles/kube-vip/README.md` — document `kube_vip_lb_dhcp_enabled`, mutual exclusion with `kube_vip_lb_ip_range`, DHCP networking prerequisites (external DHCP server, macvlan MAC support, macvlan kernel module), and per-service `loadBalancerIP: 0.0.0.0` operator action (FR-010)

---

## Phase 7: Lifecycle Integration (Install, Upgrade, and Configuration Hooks)

**Purpose**: Wire Cilium into every lifecycle entry point — fresh install, add-on deployment, version detection, and upgrade orchestration — so `cilium_enabled: true` works correctly whether invoked via `cluster-core.yml`, `cluster-addons.yml`, or `site.yml`.

### k3s Server Flag Prerequisites

- [ ] T032 Locate existing k3s server extra-args configuration by inspecting `ansible/roles/k3s-server/` and `ansible/roles/k3s-common/` task files; add `--flannel-backend=none` and `--disable-network-policy` to k3s server start flags gated on `cilium_enabled | bool` (FR-003c) — these flags MUST be set before k3s server starts, not after Cilium is installed

### Fresh Install Sequence — cluster-core.yml

- [ ] T033 Insert a Cilium play in `ansible/playbooks/cluster-core.yml` between the kube-vip play and the k3s-agent play — Cilium CNI MUST be active before agent nodes join so agents reach `Ready` state; gate the entire play on `cilium_enabled | default(false) | bool`; use `hosts: k3s_servers[0]` and `include_role: name: cilium`

### Add-on Deployment — cluster-addons.yml

- [ ] T034 [P] Add Cilium to `ansible/playbooks/cluster-addons.yml` — add `cilium` to the add-ons deployment header debug message; add `cilium_version` assertion task (must be defined and non-empty when `cilium_enabled: true`); add `include_role: name: cilium` gated on `cilium_enabled | default(false) | bool`; position before kube-vip in the play order (CNI precedes LB)

### Component Registry — site.yml Unified Orchestrator

- [ ] T035 Add `cilium` entry to `ansible/playbooks/includes/vars/component-registry.yml` — `version_var: cilium_version`, `enabled_var: cilium_enabled`, `detect_method: helm_release` with `detect_args: {release_name: cilium, namespace: kube-system}`, `fresh_install_priority: 11` (between kube-vip=10 and k3s_agents=12 — CNI must be up before agents join), `upgrade_priority: 22` (between kube-vip=20 and k3s_agents=25 — upgrade CNI after control-plane, before workers reconnect), `play_file: includes/upgrade-cilium.yml`

- [ ] T036 Create `ansible/playbooks/includes/upgrade-cilium.yml` — upgrade play that displays the version transition (live → desired), then calls `include_role: name: cilium`; follow the pattern of `includes/upgrade-addon.yml` (observed) using `component_plan.cilium` for version display

### Version Detection — detect-versions.yml

- [ ] T037 [P] Add Cilium Helm release detection to `ansible/playbooks/includes/detect-versions.yml` — detect live Cilium version via `helm list -n kube-system -o json` filtered for release name `cilium`; follow the existing Helm detection pattern used for other components; set `cilium_live_version` fact; skip detection gracefully when `cilium_enabled: false`

---

## Phase 8: Polish and Quality Gates

**Purpose**: Idempotence validation and lint compliance across all modified files.

- [ ] T038 [P] Run `rtk ansible-lint ansible/roles/kube-vip/ ansible/roles/cilium/` and resolve any lint errors in modified role files
- [ ] T039 [P] Validate idempotence — run `cluster-core.yml` and `cluster-addons.yml` twice against test inventory; confirm second run reports `changed=0` for all kube-vip and cilium tasks (FR-011)

---

## Dependencies

```
T001 → T002, T003, T004, T005
T005 → T006, T007
T006, T007, T008, T009 → [Phase 3+]

US4 (T010–T014): no US dependency; requires T001–T009
US2 (T015–T018): no US dependency; requires T001–T009
US1 (T019–T027, T024a): requires US4 (consolidated RBAC) + US2 (svc_election) + T008, T009 (Cilium role)
US3 (T028–T031): independent; requires T001–T009 (validate.yml, configmap template)

T027a: requires T009 (Cilium role exists for context); parallel with T025–T027
T032: requires T009 (Cilium role exists); implement alongside Phase 2
T033: requires T009, T032 (Cilium role with k3s flags); cluster-core.yml integration
T034: requires T033 (Cilium in cluster-core.yml); cluster-addons.yml integration
T035: requires T009 (Cilium role); component-registry.yml entry
T036: requires T035 (registry entry references upgrade-cilium.yml)
T037: requires T035 (registry entry triggers detection)

T038, T039: require all implementation tasks complete (T001–T037)
```

**Parallel opportunities per story**:
- US4: T010 (test) can run in parallel with T011–T013 (implementation); T014 (README) is parallel
- US2: T015 (test) can run in parallel with T016–T017 (implementation); T018 (README) is parallel
- US1: T020, T021 (templates) can run in parallel; T024–T027 (docs/defaults) can run in parallel after T020–T023
- US3: T028 (test) can run in parallel with T029–T030 (implementation); T031 (README) is parallel
- Phase 5 docs: T025, T026, T027, T027a can all run in parallel once T009 is complete
- Phase 7: T032 can proceed as soon as T009 is complete; T033 requires T032; T034 and T037 are parallel; T036 requires T035

---

## Implementation Strategy

**MVP scope (US4 + US2 + US1 + Phase 7)**:
1. Phase 1 setup → Phase 2 foundation → Phase 3 (US4 RBAC) → Phase 4 (US2 election) → Phase 5 (US1 egress) → Phase 7 (lifecycle integration)
2. US4 and US2 are P2 but must be implemented before US1 (P1) because US1 depends on both
3. Phase 7 lifecycle integration is required for the feature to be operationally complete — `site.yml` will not orchestrate Cilium correctly without T035–T037
4. Deliver US3 (DHCP, P3) as a follow-on increment after US1 is validated

**Evidence requirement** (§V Traceability): Each task completion MUST be backed by: test assertion pass, idempotence check (`changed=0`), or documented observation confirming the change is validated against its FR/SC requirement.
