# Quickstart Validation Guide: kubernetes.core.k8s Module Standardization

**Feature**: 004-k8s-module-refactor
**Phase**: 1 — Design
**Date**: 2026-07-04

---

## Purpose

This guide describes how to validate that the refactor is complete and correct. It covers static verification (no kubectl calls remain), idempotence verification, and functional smoke testing.

---

## Prerequisites

- A running k3s cluster with all roles previously deployed (test-cluster or equivalent)
- Ansible control node with `kubernetes.core >= 2.4.0` installed (`ansible-galaxy collection list kubernetes.core`)
- `ansible-lint` available on the control node
- Access to the test inventory (`ansible/inventories/test-cluster/`)

---

## Validation 1: Static — Zero kubectl Invocations in Refactored Roles (SC-001, SC-002)

Run from the repository root. Confirms no `kubectl` command task invocations remain in the migrated task files.

```bash
grep -rn "kubectl" \
  ansible/roles/cert-manager/tasks/ \
  ansible/roles/multus/tasks/ \
  ansible/roles/traefik/tasks/ \
  ansible/roles/kube-vip/tasks/ \
  ansible/roles/rancher/tasks/ \
  ansible/roles/rancher-monitoring/tasks/
```

**Expected outcome**: Zero matches for resource-management patterns (`kubectl apply`, `kubectl create`, `kubectl delete`, `kubectl scale`, `kubectl wait`, `kubectl rollout`).

Permitted matches (exempt tasks in kube-vip):
- `kubectl --raw=/readyz` — API health probe
- `kubectl ... api-resources` — API discovery probe
- `kubectl ... get --raw=/readyz?verbose` — diagnostic

Any other match is a regression.

---

## Validation 2: Lint — ansible-lint Must Pass (Constitution Dev Workflow Gate)

```bash
ansible-lint ansible/roles/cert-manager/
ansible-lint ansible/roles/multus/
ansible-lint ansible/roles/traefik/
ansible-lint ansible/roles/kube-vip/
ansible-lint ansible/roles/rancher/
ansible-lint ansible/roles/rancher-monitoring/
```

**Expected outcome**: Exit code 0, no warnings about use of `command`/`shell` where a module is available (which was the lint violation being resolved).

---

## Validation 3: Idempotence — Second Run Produces No Changes (SC-003)

Deploy the cluster once (first run), then run again (second run) and verify no `changed` tasks.

```bash
# First run (establishes state)
ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-core.yml

ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-addons.yml

# Second run (idempotence check)
ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-core.yml 2>&1 | tee /tmp/core-second-run.log

ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-addons.yml 2>&1 | tee /tmp/addons-second-run.log

# Check for unexpected changes
grep "changed=" /tmp/core-second-run.log
grep "changed=" /tmp/addons-second-run.log
```

**Expected outcome**: `changed=0` in the PLAY RECAP for all refactored roles on the second run. Any `changed > 0` for the in-scope roles is a regression.

Alternatively, use the idempotence smoke test directly:

```bash
ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  tests/ansible/smoke/idempotence-test.yml
```

---

## Validation 4: Functional — Full Clean Deployment (SC-004)

Deploy from scratch against a clean cluster to confirm all resources are created correctly.

```bash
ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-core.yml

ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  ansible/playbooks/cluster-addons.yml
```

**Expected outcome**:
- All plays complete with `failed=0`
- cert-manager namespace and deployments present and available
- kube-vip DaemonSet running on control-plane nodes
- multus DaemonSet and NetworkAttachmentDefinitions present
- Traefik deployment available in `kube-system`
- Rancher deployment available in `cattle-system`

Verify key resources:
```bash
kubectl get ns cert-manager cattle-system kube-system
kubectl get deploy -n cert-manager
kubectl get ds -n kube-system kube-vip kube-multus-ds
kubectl get network-attachment-definition -A
```

---

## Validation 5: Existing Smoke Tests (SC-005)

Run the existing smoke suite without modification. These tests must pass unchanged.

```bash
ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  tests/ansible/smoke/ha-disruption-test.yml

ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  tests/ansible/smoke/scale-test.yml

ansible-playbook -i ansible/inventories/test-cluster/hosts.ini \
  tests/ansible/smoke/multus-dhcp-test.yml
```

**Expected outcome**: All tests pass with `failed=0`.

---

## Key Pattern References

For implementation details of each migration pattern, see:
- [research.md](research.md) — canonical before/after patterns for all 8 migration types
- [data-model.md](data-model.md) — complete task inventory with per-role migration counts and exemptions

---

## Definition of Done

| Criterion | Validation |
|-----------|------------|
| SC-001: Zero kubectl resource commands in refactored roles | Validation 1 grep |
| SC-002: Zero kubectl get for flow-control in refactored roles | Validation 1 grep |
| SC-003: Idempotence — zero changed on second run | Validation 3 |
| SC-004: Full clean deployment succeeds | Validation 4 |
| SC-005: Existing smoke tests pass | Validation 5 |
| Lint passes | Validation 2 |
| rancher-monitoring migrated (conditional) | Validation 1 + 3 after higher-priority roles complete |
