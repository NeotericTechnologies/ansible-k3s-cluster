# Data Model: kubernetes.core.k8s Module Standardization

**Feature**: 004-k8s-module-refactor
**Phase**: 1 — Design
**Date**: 2026-07-04

---

## Overview

This feature is a task-level refactor with no data model changes to the Kubernetes cluster state, Ansible inventory, or variable files. The "data model" here describes the migration inventory — a structured record of every task invocation being changed, its pattern type, and its exemption status — used to drive task generation and validate completion.

---

## Entity 1: Migration Pattern

A canonical before/after conversion type. Each in-scope task invocation maps to exactly one migration pattern.

| Pattern ID | Old Form | New Form | Research Ref |
|-----------|----------|----------|--------------|
| P-APPLY-REMOTE | `ansible.builtin.command: kubectl apply -f https://...` | `ansible.builtin.uri` + `kubernetes.core.k8s` loop with `from_yaml_all` | R-002 |
| P-APPLY-TEMPLATE | `ansible.builtin.command: kubectl apply -f /tmp/file` preceded by `ansible.builtin.template` to `/tmp/` | `kubernetes.core.k8s` with `definition: "{{ lookup('template', ...) \| from_yaml }}"` — temp file tasks removed | R-003 |
| P-APPLY-STDIN | `ansible.builtin.command: kubectl apply -f - stdin: "{{ lookup('template', ...) }}"` | `kubernetes.core.k8s` with `definition: "{{ lookup('template', ...) \| from_yaml }}"` or `from_yaml_all` loop | R-003 |
| P-NAMESPACE | `ansible.builtin.command: kubectl create namespace ...` with AlreadyExists guard | `kubernetes.core.k8s` with `kind: Namespace`, `state: present` | R-007 |
| P-WAIT-DEPLOY | `ansible.builtin.command: kubectl wait --for=condition=available deployment ...` | `kubernetes.core.k8s_info` polling `status.availableReplicas` | R-005 |
| P-WAIT-DS | `ansible.builtin.command: kubectl rollout status daemonset/...` | `kubernetes.core.k8s_info` polling `status.numberReady == status.desiredNumberScheduled` | R-006 |
| P-SCALE | `ansible.builtin.command: kubectl scale deployment ... --replicas=N` | `kubernetes.core.k8s` partial definition patch on `spec.replicas` | R-010 |
| P-EXEMPT | Any kubectl call explicitly out of scope | Unchanged | — |

---

## Entity 2: Task Inventory

All in-scope task invocations by role and file. Status: `PENDING` (not yet migrated).

### cert-manager/tasks/install.yml

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Install cert-manager CRDs | P-APPLY-REMOTE | Multi-doc YAML; `from_yaml_all` loop |
| 2 | Create cert-manager namespace | P-NAMESPACE | |
| 3 | Deploy cert-manager | P-APPLY-REMOTE | Multi-doc YAML; `from_yaml_all` loop |
| 4 | Wait for cert-manager ready | P-WAIT-DEPLOY | Covers all 3 deployments; split into 3 explicit polls |
| 5 | Scale cert-manager | P-SCALE | `replicas: "{{ cert_manager_replicas \| default(1) }}"` |
| 6 | Scale cert-manager-webhook | P-SCALE | |
| 7 | Scale cert-manager-cainjector | P-SCALE | |
| 8 | Apply DNS credentials secret | P-APPLY-TEMPLATE | `no_log: true` must be preserved |
| 9 | Apply staging ClusterIssuer | P-APPLY-TEMPLATE | |
| 10 | Apply production ClusterIssuer | P-APPLY-TEMPLATE | |

**Temp file tasks to remove**: `dest: /tmp/cert-manager-dns-secret.yaml`, `/tmp/clusterissuer-staging.yaml`, `/tmp/clusterissuer-production.yaml` write tasks + their cleanup tasks.

### multus/tasks/install.yml

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Deploy multus thick DaemonSet and RBAC | P-APPLY-STDIN | Multi-doc template; `from_yaml_all` loop |
| 2 | Wait for multus DaemonSet ready | P-WAIT-DS | `name: kube-multus-ds`, `namespace: {{ multus_namespace }}` |
| 3 | Apply NetworkAttachmentDefinitions | P-APPLY-STDIN | Loop over `multus_vlan_networks` retained |
| 4 | Deploy multus DHCP daemon DaemonSet | P-APPLY-STDIN | Single-doc template |
| 5 | Wait for DHCP daemon DaemonSet ready | P-WAIT-DS | `name: multus-dhcp-daemon`, `namespace: {{ multus_namespace }}` |

### traefik/tasks/configure.yml

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Wait for Traefik ready | P-WAIT-DEPLOY | `name: traefik`, `namespace: kube-system` |

### kube-vip/tasks/install.yml

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Apply kube-vip DaemonSet via API | P-APPLY-TEMPLATE | `host: https://127.0.0.1:6443`, `validate_certs: false`; temp file + cleanup removed |
| 2 | Wait for kube-vip DaemonSet ready | P-WAIT-DS | `host: https://127.0.0.1:6443`, `validate_certs: false` |
| 3 | Apply kube-vip cloud controller via API | P-APPLY-TEMPLATE | Same host/validate_certs; conditional on `kube_vip_lb_enable` |
| 4 | Apply kube-vip ConfigMap via API | P-APPLY-TEMPLATE | Same host/validate_certs; conditional on `kube_vip_lb_enable` |
| — | Wait for Kubernetes API readiness (`/readyz`) | P-EXEMPT | Health probe — unchanged |
| — | Wait for API discovery (`api-resources`) | P-EXEMPT | Health probe — unchanged |
| — | Diagnostic tasks (journalctl, systemctl, readyz verbose) | P-EXEMPT | Bootstrap diagnostics — unchanged |

**Temp file tasks to remove**: `dest: /tmp/kube-vip-daemonset.yaml`, `/tmp/kube-vip-cloud-controller.yaml`, `/tmp/kube-vip-configmap.yaml` write tasks + their cleanup tasks.

### rancher/tasks/install.yml

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Create cattle-system namespace | P-NAMESPACE | |
| — | Wait for Rancher ready | P-EXEMPT (already migrated) | Already uses `kubernetes.core.k8s_info` |

### rancher-monitoring/tasks/install.yml *(lower priority)*

| # | Task Name | Pattern | Notes |
|---|-----------|---------|-------|
| 1 | Create cattle-monitoring-system namespace | P-NAMESPACE | |
| 2 | Wait for rancher-monitoring ready | P-WAIT-DEPLOY | Label selector: `app.kubernetes.io/name=grafana` |

---

## Entity 3: Exemption Registry

Tasks explicitly confirmed as exempt from migration.

| Role | Task | Reason |
|------|------|--------|
| kube-vip | `Wait for Kubernetes API readiness endpoint` (`/readyz`) | Raw HTTP probe — no kubernetes.core equivalent |
| kube-vip | `Wait for Kubernetes API discovery` (`api-resources`) | API availability check — no kubernetes.core equivalent |
| kube-vip | `Collect k3s service status for diagnostics` (`systemctl`) | Diagnostic/rescue block — no kubernetes.core equivalent |
| kube-vip | `Collect recent k3s journal logs` (`journalctl`) | Diagnostic/rescue block — no kubernetes.core equivalent |
| kube-vip | `Collect /readyz verbose output` | Diagnostic/rescue block — exempt |
| traefik | `Deploy Traefik via Helm` | Helm operation — FR-008 |
| rancher | `Install Rancher via Helm` | Helm operation — FR-008 |
| rancher-monitoring | `Install rancher-monitoring via Helm` | Helm operation — FR-008 |
| k3s-common | `collect-ha-observations.yml` kubectl get calls | Diagnostic observation — output not used for flow control |
| k3s-server | `k3s --version` | k3s binary check — FR-009 |
| k3s-agent | `k3s-agent --version` | k3s binary check — FR-009 |

---

## Migration Totals

| Role | Tasks Migrated | Tasks Exempt | Net Temp Files Removed |
|------|---------------|-------------|----------------------|
| cert-manager | 10 | 0 | 5 |
| multus | 5 | 0 | 0 |
| traefik | 1 | 1 (Helm) | 0 |
| kube-vip | 4 | 7 (probes + diagnostics) | 6 |
| rancher | 1 | 1 (already migrated) + 1 (Helm) | 0 |
| rancher-monitoring | 2 | 1 (Helm) | 0 |
| **Total** | **23** | **11** | **11** |
