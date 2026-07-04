# Implementation Plan: kubernetes.core.k8s Module Standardization

**Branch**: `004-k8s-module-refactor` | **Date**: 2026-07-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-k8s-module-refactor/spec.md`

## Summary

Standardize all Kubernetes resource operations across `cert-manager`, `multus`, `traefik`, `kube-vip`, and `rancher` roles (plus `rancher-monitoring` at lower priority, conditional on higher-priority roles completing first) to use the `kubernetes.core.k8s` and `kubernetes.core.k8s_info` Ansible modules, replacing ad-hoc `kubectl` shell invocations. The `kubernetes.core` collection (≥2.4.0) is already declared in `ansible/requirements.yml`. Migration patterns are: `kubectl apply` → `kubernetes.core.k8s` with `definition:`; `kubectl create namespace` → `kubernetes.core.k8s` with `state: present`; `kubectl wait`/`kubectl rollout status` → `kubernetes.core.k8s_info` polling loops; `kubectl scale` → `kubernetes.core.k8s` spec patch on `replicas`. Raw API health probes, Helm operations, and k3s service management are explicitly exempt.

## Technical Context

**Language/Version**: Ansible (Python-based); `kubernetes.core` collection ≥2.4.0 (already in `ansible/requirements.yml`)

**Primary Dependencies**: `kubernetes.core.k8s`, `kubernetes.core.k8s_info`, `ansible.builtin.uri` (for remote manifest fetch); all already present in the collection requirements

**Storage**: N/A — no persistent data model changes; cluster state managed via Kubernetes API

**Testing**: `ansible-lint` syntax check; idempotence smoke test (`tests/ansible/smoke/idempotence-test.yml`); existing smoke suite (`ha-disruption-test.yml`, `scale-test.yml`, `multus-dhcp-test.yml`)

**Target Platform**: Ansible control node targeting k3s cluster on Linux (x86_64/arm64); kubeconfig at `/etc/rancher/k3s/k3s.yaml`

**Project Type**: Ansible role refactor — internal, no external interface changes

**Performance Goals**: No regression in provisioning time; idempotence (zero changes on second run) is the primary non-functional requirement

**Constraints**: `validate_certs: false` and explicit `host: https://127.0.0.1:6443` required for kube-vip bootstrap-phase tasks (API not yet fully trusted); multi-document YAML manifests (cert-manager) require `from_yaml_all` filter + loop; `no_log: true` must be preserved on DNS credential secret tasks

**Scale/Scope**: 6 roles, 23 task invocations migrated; no playbook or inventory changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Refactor is internal to roles; no new playbooks or role boundaries are added |
| II. Idempotent Cluster Provisioning | PASS | Migration to `kubernetes.core.k8s` improves idempotence — `state: present` is inherently idempotent vs imperative kubectl commands |
| III. k3s-Specific Constraints (NON-NEGOTIABLE) | PASS | No k3s version, datastore, or networking changes; kube-vip bootstrap health probes preserved |
| IV. Clear Inventory and Node Roles | PASS | No inventory or host variable changes |
| V. Security, Networking, and Upgrades | PASS | No credential changes; `no_log: true` preserved on secret tasks; TLS handling unchanged |
| Ansible & k3s Requirements — idempotence validation | PASS | Idempotence smoke test is part of DoD |
| Dev Workflow — linting passes | PASS | `ansible-lint` must pass; `kubernetes.core.k8s` is the lint-preferred module over raw kubectl |

**Gate result**: PASS — no violations. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/004-k8s-module-refactor/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml               # Already contains kubernetes.core >=2.4.0 — verify, no change expected
└── roles/
    ├── cert-manager/tasks/
    │   └── install.yml            # ~10 kubectl invocations → kubernetes.core.k8s/k8s_info
    ├── multus/tasks/
    │   └── install.yml            # ~5 kubectl invocations → kubernetes.core.k8s/k8s_info
    ├── traefik/tasks/
    │   └── configure.yml          # 1 kubectl wait → kubernetes.core.k8s_info
    ├── kube-vip/tasks/
    │   └── install.yml            # 4 kubectl apply + 1 rollout status → kubernetes.core.k8s/k8s_info
    │                              #   health-probe tasks (readyz, api-resources) unchanged
    ├── rancher/tasks/
    │   └── install.yml            # 1 kubectl create namespace → kubernetes.core.k8s
    │                              #   wait already uses kubernetes.core.k8s_info (no change)
    └── rancher-monitoring/tasks/
        └── install.yml            # 1 kubectl create namespace + 1 kubectl wait → kubernetes.core.k8s/k8s_info

tests/
└── ansible/smoke/
    └── idempotence-test.yml       # Must pass unchanged — zero changes on second run
```

**Structure Decision**: Single-project in-place refactor. All changes are within existing role task files. No new files, directories, or roles are created. The `requirements.yml` is verified but not modified (collection already present at required version).
