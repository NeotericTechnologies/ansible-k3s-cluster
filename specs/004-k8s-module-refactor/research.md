# Research: kubernetes.core.k8s Module Standardization

**Feature**: 004-k8s-module-refactor
**Phase**: 0 — Research
**Date**: 2026-07-04

---

## R-001: kubernetes.core Collection Version & Availability

**Question**: Is `kubernetes.core` already declared at a sufficient version? Does any bootstrapping gap exist?

**Decision**: No change to `ansible/requirements.yml` required.

**Rationale**: `ansible/requirements.yml` already declares `kubernetes.core >= 2.4.0` and `community.kubernetes >= 3.0.0`. The `kubernetes.core.k8s` module has been stable and feature-complete since 2.3.0 — all patterns needed (multi-doc, `definition:`, `src:`, `host:`, `validate_certs:`, `kubeconfig:`) are available. The collection is already installed for `synology-csi` and `rancher` roles.

**Alternatives considered**: Pinning to an exact version (e.g., `==2.4.0`) — rejected because the minimum-version constraint already in place is appropriate for a shared collection dependency.

---

## R-002: Multi-Document YAML Manifests (cert-manager)

**Question**: `cert-manager.yaml` and `cert-manager.crds.yaml` fetched from remote URLs contain many Kubernetes resources in a single multi-document YAML file (separated by `---`). How does `kubernetes.core.k8s` handle this?

**Decision**: Use `ansible.builtin.uri` to fetch the manifest, apply `from_yaml_all` to split into a list of resource dicts, then pass to `kubernetes.core.k8s` via `definition:` in a loop.

**Pattern**:
```yaml
- name: Fetch cert-manager CRDs manifest
  ansible.builtin.uri:
    url: "https://github.com/cert-manager/cert-manager/releases/download/{{ cert_manager_version }}/cert-manager.crds.yaml"
    return_content: true
  register: cert_manager_crds_manifest

- name: Apply cert-manager CRDs
  kubernetes.core.k8s:
    definition: "{{ item }}"
    state: present
    kubeconfig: /etc/rancher/k3s/k3s.yaml
  loop: "{{ cert_manager_crds_manifest.content | from_yaml_all | list }}"
  when: item is not none
```

**Rationale**: `from_yaml_all` (Ansible Jinja2 filter) parses a multi-document YAML string into a Python list of dicts. Looping over the list allows `kubernetes.core.k8s` to apply each resource individually with full idempotence. The `when: item is not none` guard handles empty documents (trailing `---` separators).

**Change detection**: `kubernetes.core.k8s` reports `changed: true` only when the actual resource state differs from desired — eliminates the fragile stdout-parsing (`'created' in ...`) previously used.

**Alternatives considered**:
- `kubernetes.core.k8s` with `src:` pointing to a downloaded file — requires an intermediate `get_url` task and a temp file; adds complexity with no benefit.
- Keeping `kubectl apply -f https://...` — violates FR-001 and FR-012; also non-idempotent change detection.

---

## R-003: Templated Manifest Apply (multus, kube-vip, cert-manager ClusterIssuers)

**Question**: Several roles render a Jinja2 template to a `/tmp/` file then `kubectl apply -f /tmp/file.yaml`. How is this replaced without temp files?

**Decision**: Use `kubernetes.core.k8s` with `definition: "{{ lookup('template', 'template.yaml.j2') | from_yaml }}"` (single-document) or `from_yaml_all | list` (multi-document). The temp file write and cleanup tasks are eliminated entirely.

**Pattern (single-document)**:
```yaml
- name: Apply kube-vip DaemonSet
  kubernetes.core.k8s:
    definition: "{{ lookup('template', 'kube-vip-daemonset.yaml.j2') | from_yaml }}"
    state: present
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    host: https://127.0.0.1:6443
    validate_certs: false
  when: inventory_hostname == groups['k3s_servers'][0]
```

**Pattern (multi-document template — multus)**:
```yaml
- name: Apply multus DaemonSet and RBAC
  kubernetes.core.k8s:
    definition: "{{ item }}"
    state: present
    kubeconfig: "{{ multus_kubeconfig }}"
  loop: "{{ lookup('template', 'multus-daemonset-thick.yml.j2') | from_yaml_all | list }}"
  when: item is not none
```

**Rationale**: The `lookup('template', ...)` Jinja2 filter renders the template in-memory using the current playbook variable context — no disk I/O required. This is idiomatic Ansible and supported in all versions that support `kubernetes.core.k8s`. The temp file write/cleanup tasks (typically 2 tasks per manifest) are removed, reducing task count.

**Alternatives considered**: Keeping temp file approach with `kubernetes.core.k8s` and `src:` — rejected because temp files create race conditions on concurrent runs and require cleanup; in-memory rendering is cleaner.

---

## R-004: kubernetes.core.k8s for kube-vip Bootstrap Phase

**Question**: The kube-vip role applies manifests at bootstrap time using `--server https://127.0.0.1:6443 --insecure-skip-tls-verify=true`. Does `kubernetes.core.k8s` support explicit server and TLS settings?

**Decision**: Use `host: https://127.0.0.1:6443` and `validate_certs: false` module parameters on the kube-vip apply tasks. The kubeconfig is still provided to satisfy the module's authentication requirements (token/certs), but the host and TLS override are applied explicitly.

**Pattern**:
```yaml
kubernetes.core.k8s:
  definition: "{{ lookup('template', 'kube-vip-daemonset.yaml.j2') | from_yaml }}"
  state: present
  kubeconfig: /etc/rancher/k3s/k3s.yaml
  host: https://127.0.0.1:6443
  validate_certs: false
```

**Rationale**: `kubernetes.core.k8s` supports `host:`, `validate_certs:`, `ca_cert:`, `client_cert:`, and `client_key:` parameters that map directly to the kubectl `--server` and `--insecure-skip-tls-verify` flags. Using `validate_certs: false` is appropriate here because the kube-vip bootstrap sequence runs before the cluster's TLS chain is fully established; the existing API readiness checks already verify the API is reachable.

**Alternatives considered**: Running all kube-vip tasks as kubectl (exempt entire role) — rejected per clarification Q1; the DaemonSet apply runs after readiness is confirmed, so the bootstrap risk is mitigated.

---

## R-005: Deployment Readiness Polling Pattern

**Question**: `kubectl wait --for=condition=available deployment` is used in cert-manager, traefik, and rancher-monitoring. What is the canonical `kubernetes.core.k8s_info` replacement?

**Decision**: Poll with `kubernetes.core.k8s_info` on the specific Deployment resource and check `status.availableReplicas`. Use `retries` + `delay` + `until` loop.

**Pattern**:
```yaml
- name: Wait for cert-manager to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: cert-manager
    namespace: cert-manager
    kubeconfig: /etc/rancher/k3s/k3s.yaml
  register: cm_deploy
  retries: 30
  delay: 10
  until: >-
    (cm_deploy.resources | default([]) | length) > 0 and
    (cm_deploy.resources[0].status.availableReplicas | default(0) | int) >= 1
  changed_when: false
```

**Rationale**: The `rancher/tasks/install.yml` already uses this exact pattern for the Rancher deployment wait — it is proven to work in this codebase. For `kubectl wait --all -n cert-manager`, the pattern is applied once per named deployment (cert-manager, cert-manager-webhook, cert-manager-cainjector) rather than a wildcard, improving clarity.

**Note for cert-manager**: The original `kubectl wait --all` covered all deployments in the namespace simultaneously. The replacement polls each deployment individually before the scale step, which is equivalent but more explicit.

**Alternatives considered**: Using `kubernetes.core.k8s` with `wait: true` — deprecated in recent collection versions and not idiomatic for complex multi-deployment readiness. Polling is the current recommended pattern.

---

## R-006: DaemonSet Readiness Polling Pattern

**Question**: `kubectl rollout status daemonset/...` is used in multus and kube-vip. What is the canonical `kubernetes.core.k8s_info` replacement?

**Decision**: Poll `kubernetes.core.k8s_info` on the DaemonSet and compare `status.numberReady` to `status.desiredNumberScheduled`.

**Pattern**:
```yaml
- name: Wait for kube-vip DaemonSet to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: DaemonSet
    name: kube-vip
    namespace: kube-system
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    host: https://127.0.0.1:6443
    validate_certs: false
  register: kube_vip_ds
  retries: 30
  delay: 10
  until: >-
    (kube_vip_ds.resources | default([]) | length) > 0 and
    (kube_vip_ds.resources[0].status.numberReady | default(0) | int) ==
    (kube_vip_ds.resources[0].status.desiredNumberScheduled | default(-1) | int) and
    (kube_vip_ds.resources[0].status.desiredNumberScheduled | default(0) | int) > 0
  changed_when: false
```

**Rationale**: `status.numberReady == status.desiredNumberScheduled` is the structural equivalent of `kubectl rollout status` for DaemonSets. The `desiredNumberScheduled > 0` guard prevents false-positive pass when the DaemonSet has not yet scheduled any pods.

**Alternatives considered**: Polling pod list via `kubernetes.core.k8s_info` with `kind: Pod` and label selectors — more complex and fragile; DaemonSet status is the single source of truth.

---

## R-007: Namespace Creation Pattern

**Question**: `kubectl create namespace ...` (with `failed_when: 'AlreadyExists' not in stderr`) is used in cert-manager, rancher, and rancher-monitoring. What is the idiomatic replacement?

**Decision**: Use `kubernetes.core.k8s` with `kind: Namespace`, `state: present`. The module is natively idempotent — it creates if absent, makes no change if already present, and reports `changed: false` correctly.

**Pattern**:
```yaml
- name: Create cert-manager namespace
  kubernetes.core.k8s:
    api_version: v1
    kind: Namespace
    name: cert-manager
    state: present
    kubeconfig: /etc/rancher/k3s/k3s.yaml
```

**Rationale**: Eliminates the fragile `failed_when: rc != 0 and 'AlreadyExists' not in stderr` pattern. Native idempotence with correct change detection.

**Alternatives considered**: None — this is the canonical pattern.

---

## R-008: Secret Apply with no_log Preservation

**Question**: The cert-manager role applies a DNS credentials secret via `kubectl apply -f /tmp/...` with `no_log: true`. Can `kubernetes.core.k8s` preserve this?

**Decision**: Yes — `no_log: true` is a task-level directive that applies regardless of module used. Use `kubernetes.core.k8s` with `definition: "{{ lookup('template', 'dns-credentials-secret.yaml.j2') | from_yaml }}"` and `no_log: true` on the task.

**Pattern**:
```yaml
- name: Apply DNS provider credentials secret
  kubernetes.core.k8s:
    definition: "{{ lookup('template', 'dns-credentials-secret.yaml.j2') | from_yaml }}"
    state: present
    kubeconfig: /etc/rancher/k3s/k3s.yaml
  no_log: true
  when: cert_manager_dns_provider_credentials | default({}) | length > 0
```

**Rationale**: `no_log: true` suppresses Ansible's task logging at the runner level — it is module-agnostic. The template lookup is evaluated before task execution; the rendered secret values are never emitted to logs.

**Alternatives considered**: None — straightforward application of existing pattern.

---

## R-009: NetworkAttachmentDefinition Loop (multus)

**Question**: Multus applies NADs in a loop (`loop: "{{ multus_vlan_networks }}"`) using `kubectl apply -f - stdin: template`. How is this replaced?

**Decision**: Use `kubernetes.core.k8s` with `definition: "{{ lookup('template', 'network-attachment-definition.yaml.j2') | from_yaml }}"` in the same loop. The loop variable (`item`) is available to the template lookup in loop context.

**Pattern**:
```yaml
- name: Apply NetworkAttachmentDefinitions
  kubernetes.core.k8s:
    definition: "{{ lookup('template', 'network-attachment-definition.yaml.j2') | from_yaml }}"
    state: present
    kubeconfig: "{{ multus_kubeconfig }}"
  loop: "{{ multus_vlan_networks }}"
  when: multus_vlan_networks | default([]) | length > 0
```

**Rationale**: Within a `loop:` context, `lookup('template', ...)` has access to the current `item` variable, so per-network variables are correctly resolved per iteration. Native idempotence eliminates the fragile stdout-change-detection pattern.

**Alternatives considered**: Using `kubernetes.core.k8s` with `definition:` as a list (all NADs at once) — not possible because each NAD depends on the loop `item` variable; per-iteration rendering is required.

---

## R-010: kubectl scale → kubernetes.core.k8s Replicas Patch

**Question**: cert-manager scales deployments via `kubectl scale deployment ... --replicas=`. How is this replaced idempotently?

**Decision**: Use `kubernetes.core.k8s` with `definition:` containing only the `spec.replicas` field (strategic merge patch). The module will patch only the replicas field without affecting other deployment spec fields.

**Pattern**:
```yaml
- name: Scale cert-manager to topology-aware replica target
  kubernetes.core.k8s:
    api_version: apps/v1
    kind: Deployment
    name: cert-manager
    namespace: cert-manager
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    definition:
      spec:
        replicas: "{{ cert_manager_replicas | default(1) | int }}"
  when: cert_manager_replicas is defined
```

**Rationale**: `kubernetes.core.k8s` performs a strategic merge patch when a partial `definition:` is provided — only `spec.replicas` is updated. This is idempotent: re-running when replicas are already at the target value reports `changed: false`.

**Note**: The `when: cert_manager_replicas is defined` condition ensures the scale task is skipped if no override is set, allowing the chart's default replica count to stand.

**Alternatives considered**: Providing the full Deployment spec — unnecessarily broad, risks unintended field mutations; partial patch is preferred.
