# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-16 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Deliver a baseline Ansible-driven lifecycle for k3s clusters that covers provisioning, idempotent updates, node scaling, controlled minor/patch upgrades, and optional platform add-ons. For control-plane and service endpoint stability, standardize kube-vip installation as a DaemonSet and drive all behavior via inventory and variables.

## Technical Context

**Language/Version**: YAML-based Ansible playbooks and roles (Ansible Core 2.15+)

**Primary Dependencies**: `ansible-core`, `ansible-lint`, k3s binaries, Helm charts for Rancher/rancher-monitoring, Kubernetes manifests/templates for cert-manager, multus, Traefik, kube-vip, Synology CSI

**Storage**: Embedded etcd for HA control-plane (default); optional Synology CSI-backed persistent storage

**Testing**: `ansible-lint`, `ansible-playbook --check`, smoke tests under `tests/ansible/smoke/`

**Target Platform**: systemd-based Debian/Ubuntu Linux on x86_64 and arm64, reachable by SSH

**Project Type**: Infrastructure-as-code Ansible repository

**Performance Goals**: Prioritize correctness and idempotence over strict timing SLOs; complete small HA cluster bootstrap in operationally acceptable time

**Constraints**: No destructive default behavior; no secret material in repository; major k3s upgrades out of scope; kube-vip must be configured via variables and deployed as DaemonSet

**Scale/Scope**: Single-node and small HA clusters (1-3 control-plane, up to ~10 workers)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Principle I (Minimal, Focused Playbooks): PASS
  - Core cluster lifecycle and add-ons are separated into dedicated playbooks and roles.
- Principle II (Idempotent Cluster Provisioning): PASS
  - Plan enforces idempotence through module-based tasks, `--check`, and repeated-run smoke tests.
- Principle III (k3s-Specific Constraints): PASS
  - k3s version pinning, server/agent role separation, and controlled minor/patch upgrade path are explicit.
- Principle IV (Clear Inventory and Node Roles): PASS
  - Inventory groups `k3s_servers` and `k3s_agents` are required and drive behavior.
- Principle V (Security, Networking, Upgrades): PASS
  - Secure defaults, explicit networking variables, and documented upgrade flow are included.

Post-Design Re-check (after Phase 1 artifacts): PASS

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-ansible-baseline/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── lifecycle-contracts.md
└── tasks.md
```

### Source Code (repository root)

```text
ansible/
├── group_vars/
├── host_vars/
├── inventories/
├── playbooks/
│   ├── cluster-core.yml
│   ├── cluster-addons.yml
│   ├── scale-nodes.yml
│   └── upgrade-k3s.yml
└── roles/
    ├── k3s-common/
    ├── k3s-server/
    ├── k3s-agent/
    ├── kube-vip/
    ├── cert-manager/
    ├── multus/
    ├── traefik/
    ├── rancher/
    ├── rancher-monitoring/
    └── synology-csi/

tests/
└── ansible/
    └── smoke/
```

**Structure Decision**: Use the existing Ansible monorepo structure with role-scoped responsibilities and dedicated lifecycle playbooks. Keep kube-vip behavior encapsulated in `ansible/roles/kube-vip/` with DaemonSet-oriented templates and variables.

## Phase 0: Research Focus

- Confirm kube-vip deployment pattern and baseline decision for DaemonSet mode.
- Validate idempotence and rerun-safe role composition for core + add-ons playbooks.
- Validate inventory and variable contracts for HA and single-node topologies.

## Phase 1: Design Outputs

- Update data model with explicit kube-vip deployment mode (`daemonset`) and service load balancer address handling.
- Update lifecycle contracts with DaemonSet-specific expected outcomes and operator inputs.
- Update quickstart guidance to call out kube-vip DaemonSet requirements and verification.

## Complexity Tracking

No constitution violations identified; complexity exceptions are not required.
