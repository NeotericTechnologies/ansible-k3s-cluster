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

All tasks MUST comply with these constraints per R-013 and R-016:

1. **No symlinks on nodes** — roles must not create symlinks on target nodes for any deployment artifact
2. **No file copies to nodes for runtime workloads** — add-ons (kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI) must be deployed as in-cluster resources via the Kubernetes API (Helm charts, manifests via `kubernetes.core` modules), not by copying files to the node filesystem. DaemonSet initContainers that install binaries to the k3s CNI bin dir are the approved exception.
3. **No modification of default k3s paths** — roles must not remove, rename, or alter paths managed by k3s (`/var/lib/rancher/k3s`, `/etc/rancher/k3s`, etc.). Adding CNI plugin binaries to `/var/lib/rancher/k3s/data/current/bin` via initContainers is permitted.
4. **No Ansible-time binary installation on nodes** — the `dhcp` binary MUST NOT be installed on nodes via Ansible `get_url`/`tar`/`copy`. It must be deployed via a DaemonSet initContainer that copies it from a CNI plugins container image (R-016).

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

### Add-on Roles: multus (Manifest, Thick Plugin, DaemonSet)

- [X] T032 [P] [US1] Define multus role defaults in ansible/roles/multus/defaults/main.yml (enabled flag, multus image tag, k3s CNI conf dir override `/var/lib/rancher/k3s/agent/etc/cni/net.d`, k3s CNI bin dir override `/var/lib/rancher/k3s/data/current/bin`, vlan_networks list)
- [X] T033 [P] [US1] Create multus DaemonSet manifest template in ansible/roles/multus/templates/multus-daemonset-thick.yaml.j2 (upstream thick plugin DaemonSet with k3s CNI path overrides)
- [X] T033b [P] [US1] Create NetworkAttachmentDefinition template in ansible/roles/multus/templates/network-attachment-definition.yaml.j2
- [X] T034 [US1] Implement multus install tasks in ansible/roles/multus/tasks/install.yml (apply thick plugin DaemonSet manifest via kubernetes.core.k8s with k3s path overrides, wait for DaemonSet ready, apply NetworkAttachmentDefinitions)
- [X] T034b [US1] Implement multus main task file in ansible/roles/multus/tasks/main.yml (gate on enabled flag, include install.yml)
- [X] T090 [P] [US1] Add multus_dhcp_daemon_enabled variable to ansible/roles/multus/defaults/main.yml (explicit boolean, defaults to `true`; operator may override to `false` to skip DHCP daemon even when dhcp IPAM is configured — runtime Jinja2 conditional in install.yml gates actual deployment)
- [X] T091 [P] [US1] Create multus DHCP daemon DaemonSet template in ansible/roles/multus/templates/multus-dhcp-daemon.yaml.j2 (runs DHCP daemon pod on each node, listens on UNIX socket for DHCP proxy requests)
- [X] T092 [US1] Update NetworkAttachmentDefinition template in ansible/roles/multus/templates/network-attachment-definition.yaml.j2 to support ipam_type: dhcp (render `"ipam": {"type": "dhcp"}` when vlan_network.ipam_type is dhcp)
- [X] T093 [US1] Update multus install tasks in ansible/roles/multus/tasks/install.yml to deploy DHCP daemon DaemonSet when multus_dhcp_daemon_enabled is true

### R-016 Migration: DHCP Daemon initContainer Deployment

**Purpose**: Migrate the DHCP daemon from Ansible-time binary installation (`get_url`/`tar` on nodes) to the approved initContainer pattern per R-016. The `dhcp` binary must be installed by a DaemonSet initContainer that downloads the official containernetworking/plugins release tarball from GitHub and extracts it into the k3s CNI bin dir (`/var/lib/rancher/k3s/data/current/bin`).

- [X] T096 [US1] Update multus role defaults in ansible/roles/multus/defaults/main.yml — remove `multus_dhcp_daemon_image: "busybox:stable"` and `multus_cni_plugins_version` variables; add `multus_dhcp_daemon_image` (minimal image with shell and curl, e.g. `alpine:3`, used for both the initContainer and main container), and `multus_cni_plugins_version` (version of the official containernetworking/plugins release tarball to download, e.g. `v1.6.2`). Keep `multus_cni_bin_dir` default at `/var/lib/rancher/k3s/data/current/bin` (canonical path — DO NOT CHANGE)
- [X] T097 [US1] Rewrite DHCP daemon DaemonSet template in ansible/roles/multus/templates/multus-dhcp-daemon.yaml.j2 — add initContainer `install-cni-plugins` that uses `{{ multus_dhcp_daemon_image }}` (e.g. `alpine:3`) to download the official containernetworking/plugins tarball from `https://github.com/containernetworking/plugins/releases/download/{{ multus_cni_plugins_version }}/cni-plugins-linux-<arch>-{{ multus_cni_plugins_version }}.tgz`, extract only the `dhcp` binary, and copy it to the host CNI bin dir volume mount at `/host/cni-bin/dhcp`; retain initContainer `clean-dhcp-socket` (removes stale `/run/cni/dhcp.sock`); update main container `dhcp-daemon` to use `{{ multus_dhcp_daemon_image }}` and run `/host/cni-bin/dhcp daemon -hostprefix /host` from the host-mounted CNI bin dir; ensure volumes: cni-bin (hostPath `{{ multus_cni_bin_dir }}`), run-cni (hostPath `/run/cni`), proc (hostPath `/proc`), netns (hostPath `/run/netns` with HostToContainer propagation)
- [X] T098 [US1] Remove Ansible-time dhcp binary installation from ansible/roles/multus/tasks/install.yml — delete the entire `Install CNI dhcp binary on nodes` block (stat check, get_url download, tar extraction, chmod, cleanup tasks that delegate_to each node); the dhcp binary is now managed entirely by the DaemonSet initContainer
- [X] T100 [P] [US1] Update multus role README in ansible/roles/multus/README.md — document the initContainer-based DHCP binary deployment approach, reference R-016, document that Ansible does NOT install any binaries on nodes, list the required variables (`multus_cni_plugins_image`, `multus_cni_plugins_version`, `multus_dhcp_daemon_image`, `multus_cni_bin_dir`)
- [X] T101 [US1] Verify multus DHCP daemon DaemonSet deploys correctly via ansible/roles/multus/tasks/install.yml — ensure the kubernetes.core.k8s apply of the updated template succeeds, DaemonSet rolls out with initContainer completing before main container starts
- [X] T104 [US1] Add DHCP daemon validation check to ansible/roles/multus/tasks/install.yml — before deploying NADs, assert that `multus_dhcp_daemon_enabled` is `true` when any entry in `multus_vlan_networks` has `ipam_type: dhcp` (or omits ipam_type, since dhcp is the default); fail with a clear message: "DHCP daemon must be enabled when VLAN networks use ipam_type: dhcp"

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

- [X] T044 [P] [US1] Define synology-csi role defaults in ansible/roles/synology-csi/defaults/main.yml (enabled flag, version, namespace, endpoint, port 8443, tls_verify false, snapshots_enabled, storage_classes list with protocol iscsi|nfs)
- [X] T045 [P] [US1] Create Synology CSI client-info secret template in ansible/roles/synology-csi/templates/client-info-secret.yaml.j2 (NAS endpoint, HTTPS:8443, credentials, self-signed cert acceptance)
- [X] T046 [P] [US1] Create iSCSI StorageClass template in ansible/roles/synology-csi/templates/storageclass-iscsi.yaml.j2 (protocol-specific parameters, reclaim policy, volume binding mode)
- [X] T046b [P] [US1] Create NFS StorageClass template in ansible/roles/synology-csi/templates/storageclass-nfs.yaml.j2 (protocol-specific parameters, reclaim policy, volume binding mode)
- [X] T046c [P] [US1] Create VolumeSnapshotClass template in ansible/roles/synology-csi/templates/volumesnapshotclass.yaml.j2 (Synology CSI driver, deletion policy)
- [X] T046d [P] [US1] Create Synology CSI namespace template in ansible/roles/synology-csi/templates/namespace.yaml.j2
- [X] T046e [P] [US1] Create Synology CSI node DaemonSet template in ansible/roles/synology-csi/templates/node-daemonset.yaml.j2 (CSI node plugin for attach/mount on each node)
- [X] T046f [P] [US1] Create Synology CSI controller template in ansible/roles/synology-csi/templates/controller.yaml.j2 (CSI controller for provisioning/snapshotting)
- [X] T046g [P] [US1] Create Synology CSI snapshotter controller template in ansible/roles/synology-csi/templates/snapshotter.yaml.j2 (deployed when snapshots_enabled is true)
- [X] T047 [US1] Implement synology-csi install tasks in ansible/roles/synology-csi/tasks/install.yml (create namespace, deploy client-info secret, deploy node DaemonSet, deploy controller, conditionally deploy snapshotter, create StorageClasses per protocol, conditionally create VolumeSnapshotClass)
- [X] T047b [US1] Implement synology-csi main task file in ansible/roles/synology-csi/tasks/main.yml (gate on enabled flag, include install.yml)

### Add-on Roles: csi-driver-nfs (NFS Sub-Directory Provisioning)

- [X] T079 [P] [US1] Add csi_nfs_* variables to synology-csi role defaults in ansible/roles/synology-csi/defaults/main.yml (csi_nfs_enabled, csi_nfs_version, csi_nfs_server, csi_nfs_share)
- [X] T080 [P] [US1] Create csi-driver-nfs Helm values template in ansible/roles/synology-csi/templates/csi-driver-nfs-values.yaml.j2 (driver name nfs.csi.k8s.io, node and controller settings)
- [X] T081 [P] [US1] Create NFS sub-directory StorageClass template in ansible/roles/synology-csi/templates/storageclass-nfs-subdir.yaml.j2 (provisioner nfs.csi.k8s.io, server, share path, subDir template, reclaim policy, volume binding mode)
- [X] T082 [US1] Implement csi-driver-nfs install tasks in ansible/roles/synology-csi/tasks/csi-driver-nfs.yml (add Helm repo, deploy csi-driver-nfs chart with values template, wait for DaemonSet/controller ready, create nfs-subdir StorageClass)
- [X] T083 [US1] Update synology-csi main task file ansible/roles/synology-csi/tasks/main.yml to conditionally include csi-driver-nfs.yml when csi_nfs_enabled is true

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
- [X] T055 [P] [US2] Add idempotent convergence logic to ansible/roles/multus/tasks/install.yml (manifest template diff detection, DaemonSet update on change, NetworkAttachmentDefinition update without recreation)
- [X] T094 [P] [US2] Add idempotent convergence logic for DHCP daemon in ansible/roles/multus/tasks/install.yml (deploy/remove DHCP daemon DaemonSet based on multus_dhcp_daemon_enabled, update NADs when ipam_type changes)
- [X] T102 [P] [US2] Verify idempotent convergence for R-016 DHCP daemon DaemonSet in ansible/roles/multus/tasks/install.yml — re-running with same variables produces no changes; changing `multus_cni_plugins_version` triggers DaemonSet update with new initContainer image; toggling `multus_dhcp_daemon_enabled` to false removes DaemonSet cleanly
- [X] T056 [P] [US2] Add idempotent convergence logic to ansible/roles/synology-csi/tasks/install.yml (namespace, secret, DaemonSet, controller, snapshotter, StorageClass, and VolumeSnapshotClass update without recreation)
- [X] T084 [P] [US2] Add idempotent convergence logic to ansible/roles/synology-csi/tasks/csi-driver-nfs.yml (Helm upgrade with changed values only, StorageClass update without recreation)
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
- [X] T077 [P] Create Synology CSI PVC validation smoke test in tests/ansible/smoke/synology-pvc-test.yml (create PVC against both iSCSI and NFS StorageClasses, bind, write data, verify availability; optionally test VolumeSnapshot creation — validates SC-005)
- [X] T085 [P] Update Synology PVC smoke test in tests/ansible/smoke/synology-pvc-test.yml to also validate csi-driver-nfs nfs-subdir StorageClass (create PVC, verify sub-directory created on NFS share, bind, write data)
- [X] T078 [P] Create DNS-01 provider switch validation smoke test in tests/ansible/smoke/dns-provider-switch-test.yml (change dns_provider variable, re-run cert-manager role, verify issuer renewal with new provider — validates SC-007)
- [X] T095 [P] Create multus DHCP smoke test in tests/ansible/smoke/multus-dhcp-test.yml (deploy a pod with a NetworkAttachmentDefinition using ipam_type: dhcp, verify pod gets a secondary interface with a DHCP-assigned IP, verify DHCP daemon DaemonSet is running)
- [X] T103 [P] Update multus DHCP smoke test in tests/ansible/smoke/multus-dhcp-test.yml — add validation that: DHCP daemon DaemonSet has initContainer `install-cni-plugins` that completed successfully, `dhcp` binary exists at the expected CNI bin dir path on nodes (via exec into DaemonSet pod), no Ansible-managed dhcp binary exists outside the DaemonSet lifecycle

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
- R-016 migration tasks (T096–T101) depend on existing multus tasks being complete (T032–T093)

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002–T006)
- Within US1: all role defaults (T012, T013, T019, T026, T032, T035, T038, T041, T044) can run in parallel
- Within US1: all templates for a given role marked [P] can run in parallel
- Within US1: csi-driver-nfs tasks T079, T080, T081 can run in parallel (different files)
- Within US1 R-016: T100 can run in parallel with T097–T099 (README vs code changes)
- Within US2: all idempotent convergence tasks (T050–T056, T084, T102) can run in parallel (different role files)
- All Polish phase documentation tasks (T068–T074) can run in parallel
- All smoke test playbooks (T064–T067, T085, T103) can run in parallel

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
Task: T033 "Create multus DaemonSet manifest template (thick plugin, k3s paths)"
Task: T033b "Create NetworkAttachmentDefinition template"
Task: T091 "Create multus DHCP daemon DaemonSet template"

# R-016 migration (after existing multus tasks complete):
# Sequential (dependencies within):
Task: T096 "Update multus role defaults (CNI plugins image, k3s data/cni path)"
Task: T097 "Rewrite DHCP daemon DaemonSet template (initContainer approach)"
Task: T098 "Remove Ansible-time dhcp binary installation from install.yml"
# Parallel with above:
Task: T100 "Update multus role README (document initContainer approach)"
# After T097-T098:
Task: T101 "Verify DHCP daemon DaemonSet deploys correctly"
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
- Multus MUST be installed via the upstream thick plugin DaemonSet manifest (templated for k3s CNI path overrides) applied via `kubernetes.core.k8s`, per R-008
- All add-on deployments MUST comply with k3s compatibility constraints: no symlinks on nodes, no file copies for runtime workloads, no modification of default k3s paths
- Synology CSI deployment includes: namespace, client-info secret (HTTPS:8443, self-signed), node DaemonSet, controller, snapshotter (optional), iSCSI and/or NFS StorageClasses, VolumeSnapshotClass (optional)
- Secrets (tokens, DNS credentials, Synology credentials) must NEVER be committed — use Ansible Vault or external secret management
- Commit after each task or logical group
