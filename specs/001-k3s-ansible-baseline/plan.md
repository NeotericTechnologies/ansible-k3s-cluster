# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-02-16 | **Spec**: [specs/001-k3s-ansible-baseline/spec.md](specs/001-k3s-ansible-baseline/spec.md)
**Input**: Feature specification from `/specs/001-k3s-ansible-baseline/spec.md`

**Note**: This plan is filled by the `/speckit.plan` workflow for the k3s cluster lifecycle Ansible playbook.

## Summary

Implement a set of Ansible playbooks and roles that manage the complete lifecycle of a k3s cluster: provisioning a new HA cluster (embedded etcd, control-plane behind a VIP/load balancer), updating configuration for existing clusters, and adding/removing control-plane and worker nodes. One core playbook provisions and updates the k3s cluster itself, while a separate add-ons playbook installs and manages optional platform components (cert-manager with provider-agnostic DNS-01 issuers, multus for VLAN-based pod networking, Rancher and rancher-monitoring, Traefik, and optional Synology CSI-backed storage) that can be enabled or disabled via variables. All playbooks remain idempotent, k3s-specific, and driven entirely from inventory and variables.

## Technical Context

**Language/Version**: Ansible playbooks (YAML); minimum supported Ansible Core version 2.15+
**Primary Dependencies**: Ansible, k3s, k3s-io/k3s-ansible collection, cert-manager, multus CNI, Rancher and rancher-monitoring stack, Traefik ingress, kube-vip (or equivalent LB/VIP mechanism) for control-plane VIP and service load balancing, optional Synology CSI driver
**Storage**: Embedded etcd for k3s control-plane state; optional Synology CSI-backed persistent volumes for workloads
**Testing**: ansible-lint and `ansible-playbook --check` as the mandatory baseline; Molecule-based role tests are potential follow-up work, not required for this feature
**Target Platform**: Linux servers (e.g., Debian/Ubuntu family, systemd-based, x86_64/arm64) reachable via SSH, as per constitution
**Project Type**: Single infra automation project (Ansible playbooks and roles, no separate frontend/backend applications)
**Performance Goals**: No strict numeric SLOs for this baseline; design targets correctness and idempotence for small-to-medium HA clusters, with provisioning time primarily constrained by environment
**Constraints**: Idempotent runs; safe minor/patch k3s upgrades only; k3s-specific behavior (no kubeadm assumptions); no explicit hard limit on maximum cluster size in this feature
**Scale/Scope**: Reference examples will target 1–3 control-plane nodes and a handful of workers (for example, up to ~10), while keeping the design structurally capable of larger clusters without guaranteeing behavior at very large scale

**Non-Goals**:
- Full disaster-recovery orchestration (for example, complete etcd loss or rebuild-from-backup flows) is out of scope for this feature; the playbooks focus on healthy-to-healthy lifecycle and partial-failure recovery via safe re-runs.
- Large-scale cluster operations (dozens/hundreds of nodes) and advanced autoscaling scenarios are not targeted; they may require additional tooling and tuning beyond this baseline.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Gate C1 – Minimal, Focused Playbooks**: Scope is limited to the k3s cluster lifecycle as the core concern, with platform add-ons (networking, ingress, certificates, monitoring, optional storage) provided via a separate add-ons playbook and conditional variables so that the core cluster can be provisioned independently. No application workloads are included. **Status: PASS (confirmed after Phase 1 design)**.
- **Gate C2 – Idempotent Cluster Provisioning**: Roles are planned to be idempotent and safe to re-run (modules over raw shell, guarded destructive actions, safe upgrades), with lint/check-mode and smoke tests supporting this. **Status: PASS (design and validation approach defined)**.
- **Gate C3 – k3s-Specific Constraints (NON-NEGOTIABLE)**: Design pins k3s version via variables, uses embedded etcd HA, and explicitly scopes out major version upgrades. **Status: PASS**.
- **Gate C4 – Clear Inventory and Node Roles**: Inventory and data model define explicit groups (`k3s_servers`, `k3s_agents`) and host vars for labels/taints, with no hard-coded hosts. **Status: PASS**.
- **Gate C5 – Security, Networking, and Upgrades**: Networking and VIP/load-balancer patterns (kube-vip) are modeled in the data model and contracts; only controlled minor/patch upgrades are supported as per clarification. **Status: PASS**.

No constitution violations are currently anticipated after Phase 1; Complexity Tracking remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-ansible-baseline/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
ansible/
├── inventories/
│   ├── examples/
│   └── production/
├── group_vars/
├── host_vars/
├── roles/
│   ├── k3s-common/
│   ├── k3s-server/
│   ├── k3s-agent/
│   ├── kube-vip/           # control-plane VIP and service LB
│   ├── cert-manager/
│   ├── multus/
│   ├── rancher/
│   ├── rancher-monitoring/
│   ├── traefik/
│   └── synology-csi/
└── playbooks/
    ├── cluster-core.yml     # core create/update cluster
    ├── cluster-addons.yml   # optional platform add-ons
    ├── scale-nodes.yml      # add/remove control-plane and worker nodes
    └── upgrade-k3s.yml      # minor/patch k3s upgrades

tests/
└── ansible/
    ├── inventories/
    └── smoke/             # simple smoke tests and check-mode runs
```

**Structure Decision**: Use a single Ansible-focused project rooted under `ansible/` with standard inventories, group/host vars, and roles dedicated to each platform component (k3s core, kube-vip for VIP/LB, cert-manager, multus, Rancher stack, Traefik, Synology CSI). Playbooks under `ansible/playbooks/` map directly to the primary user workflows (provision/update the core cluster, apply optional add-ons, scale nodes, perform minor/patch upgrades). A lightweight `tests/ansible/` tree will host inventories and smoke tests rather than a separate service/application codebase.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|

