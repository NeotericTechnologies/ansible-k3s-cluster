# Implementation Plan: HA Component Deployment

**Branch**: `003-create-feature-branch` | **Date**: 2026-07-01 | **Spec**: [spec.md](specs/003-ha-component-deployment/spec.md)

**Input**: Feature specification from `/specs/003-ha-component-deployment/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Apply topology-aware HA behavior for all repository-managed core and addon components when inventory defines three or more server nodes. The implementation will centralize component-specific HA minimum targets in the same top-level variable locations as component versions, enforce hard-fail validation when enabled component targets are unmet, and keep behavior consistent across provisioning, scaling, and upgrade lifecycle playbooks.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Ansible Core 2.15+ (YAML playbooks and Jinja2 templates)

**Primary Dependencies**: Ansible roles/playbooks under `ansible/playbooks` and `ansible/roles`, `kubernetes.core` modules, Helm-managed addons where already used

**Storage**: Git repository configuration files (`ansible/group_vars`, inventory `group_vars`, role defaults) and Kubernetes cluster state for runtime validation

**Testing**: `ansible-lint`, `ansible-playbook --check`, smoke playbooks under `tests/ansible/smoke`, and post-run availability assertions

**Target Platform**: systemd-based Debian/Ubuntu-like Linux nodes running k3s clusters managed over SSH by Ansible

**Project Type**: Infrastructure-as-code automation repository (Ansible)

**Performance Goals**: In HA topology, 100% of enabled in-scope components meet documented HA minimum targets; critical subset availability >=99% during single-node disruption window

**Constraints**: Preserve non-HA defaults for <3 server clusters, preserve explicit operator overrides, fail run on HA target violations, and keep HA target variables at same top-level scope as corresponding component version variables

**Scale/Scope**: All repository-managed roles/components (`k3s-common`, `k3s-server`, `k3s-agent`, `kube-vip`, `cert-manager`, `multus`, `traefik`, `rancher`, `rancher-monitoring`, `synology-csi`) across `cluster-core.yml`, `cluster-addons.yml`, `scale-nodes.yml`, and `upgrade-k3s.yml`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | HA logic is scoped to existing managed components and current lifecycle playbooks; no new unrelated deployment scope |
| II. Idempotent Cluster Provisioning | PASS | HA target enforcement is declarative and validation-based with re-runnable assertions |
| III. k3s-Specific Constraints | PASS | Topology detection derives from `k3s_servers` inventory and preserves pinned, configurable k3s behavior |
| IV. Clear Inventory and Node Roles | PASS | HA/non-HA classification explicitly depends on inventory server count; no hostname hard-coding |
| V. Security, Networking, and Upgrades | PASS | Changes are configuration-driven, avoid secrets in repo, and require lifecycle consistency through upgrade/scale flows |

### Post-Phase 1 Re-Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Data model and contracts constrain scope to existing component roles/playbooks only |
| II. Idempotent Cluster Provisioning | PASS | Contracts require hard-fail validation on unmet HA targets with repeatable checks |
| III. k3s-Specific Constraints | PASS | Design keeps k3s version pinning and inventory-driven role semantics intact |
| IV. Clear Inventory and Node Roles | PASS | HA policy entity model is keyed by component and topology profile from inventory groups |
| V. Security, Networking, and Upgrades | PASS | Quickstart includes lifecycle validation across provision/scale/upgrade without widening exposed defaults |

## Project Structure

### Documentation (this feature)

```text
specs/003-ha-component-deployment/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── ha-lifecycle-contracts.md
└── tasks.md
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
ansible/
├── playbooks/
│   ├── cluster-core.yml
│   ├── cluster-addons.yml
│   ├── scale-nodes.yml
│   └── upgrade-k3s.yml
├── group_vars/
│   └── all.yml
├── inventories/
│   ├── examples/
│   └── test-cluster/group_vars/
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
└── ansible/smoke/

docs/
└── ansible-k3s-baseline.md
```

**Structure Decision**: Keep the current roles-and-playbooks Ansible structure and implement HA behavior through variable model extensions plus lifecycle validation tasks inside existing playbooks/roles.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations requiring justification.
