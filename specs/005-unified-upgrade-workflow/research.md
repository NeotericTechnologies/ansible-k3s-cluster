# Research: Unified Upgrade Workflow

**Feature**: 005-unified-upgrade-workflow
**Date**: 2026-07-05

## Research Tasks

### 1. Ansible patterns for unified install/upgrade playbooks

**Decision**: Use a single orchestrator playbook (`site.yml`) that imports component plays conditionally based on detected version drift.

**Rationale**: Ansible's `import_playbook` with `when` conditions provides clean separation while allowing a single entry point. This pattern is well-established in large Ansible projects (e.g., kubespray). The existing role structure is preserved — the orchestrator simply wraps the existing plays with version-detection logic.

**Alternatives considered**:
- Single monolithic playbook with all tasks inline → Rejected: violates constitution principle of minimal focused playbooks, harder to maintain.
- Meta-role that includes other roles → Rejected: Ansible role dependencies are complex and don't support the play-level `serial` needed for rolling k3s upgrades.
- Tags-only approach (all in one, run with tags) → Rejected: tags don't support conditional execution based on runtime state; operator must still know which tags to use.

### 2. Live version detection patterns in Ansible

**Decision**: Use a pre-flight "gather state" play that runs on `k3s_servers[0]` to:
- Query `k3s --version` on each node via delegated commands
- Query `helm list -A -o json` for Helm-deployed components (Rancher, cert-manager, traefik, rancher-monitoring)
- Check kube-vip and multus via their deployed manifest versions (label/annotation queries)

**Rationale**: Querying the live cluster is the most reliable source of truth (per clarification). It handles partially-failed prior runs. The first server node already has kubeconfig access. helm/kubectl commands are already used in existing playbooks.

**Alternatives considered**:
- Ansible facts cache with version state file → Rejected: stale if playbook is aborted mid-run.
- Compare only variables → Rejected: doesn't detect actual deployed state.

### 3. Dependency graph representation in group_vars

**Decision**: Define a `component_compatibility` variable in `group_vars/all.yml` as a dictionary mapping component pairs to version constraints. The orchestrator reads this to determine ordering and validate constraints.

**Rationale**: Per clarification, the operator chose group_vars over a separate file. A dictionary structure is native to Ansible, requires no custom plugins, and can be overridden per-inventory for different environments.

**Structure**:
```yaml
component_compatibility:
  rancher:
    k3s_max_version: "v1.30.99+k3s99"  # Rancher 2.9 supports up to k3s 1.30.x
    k3s_min_version: "v1.27.0+k3s1"
  cert_manager:
    k3s_min_version: "v1.25.0+k3s1"    # cert-manager requires k3s 1.25+
```

**Alternatives considered**:
- Dedicated `compatibility.yml` file → Rejected per clarification.
- Hard-coded in role vars → Rejected: not overridable per environment.

### 4. Upgrade ordering logic

**Decision**: Fixed priority order with dependency validation:
1. Validate all nodes reachable
2. Validate version constraints (fail-fast)
3. Print upgrade plan summary
4. Upgrade Rancher (if version changed) — must happen before k3s
5. Upgrade k3s servers (serial: 1, with cordon/drain/uncordon)
6. Upgrade k3s agents (serial: 1, with cordon/drain/uncordon)
7. Upgrade remaining add-ons (cert-manager, traefik, multus, synology-csi, rancher-monitoring) — order doesn't matter, all are independent of each other

**Rationale**: Rancher defines the max k3s version (per clarification), so it must be upgraded first to expand the compatibility window before k3s is upgraded. Other add-ons are independent of each other and of k3s minor version within reason.

**Alternatives considered**:
- Dynamic topological sort of dependency DAG → Over-engineering for the known fixed dependencies in this project. The relationships are simple and well-defined.
- Parallel add-on upgrades → Rejected: Ansible doesn't natively support parallel plays, and serial execution is safer.

### 5. Cordon/drain patterns for k3s nodes

**Decision**: Before upgrading k3s on a node:
1. `kubectl cordon <node>` — prevent new scheduling
2. `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=300s` — evict workloads
3. Perform k3s upgrade (reinstall with new version)
4. Wait for node Ready
5. `kubectl uncordon <node>` — allow scheduling again

**Rationale**: Standard Kubernetes practice. The existing `upgrade-k3s.yml` doesn't cordon/drain (it just upgrades in-place), which is a gap this feature fills. The `--ignore-daemonsets` flag is needed because DaemonSets can't be evicted. The `--delete-emptydir-data` flag is needed because emptyDir volumes prevent drain otherwise.

**Alternatives considered**:
- Skip drain for patch upgrades → Considered but rejected: even patch upgrades restart the kubelet, causing brief workload disruption. Drain ensures graceful eviction.
- PodDisruptionBudget-aware drain only → Drain already respects PDBs natively.

### 6. Downgrade detection and blocking

**Decision**: Compare detected live version against desired version using Ansible's `version` test filter. If `desired < live` and `allow_downgrade` is not true, fail with clear message.

**Rationale**: Ansible has built-in version comparison via the `version` Jinja2 test. Simple, no custom code needed.

### 7. Unreachable node detection

**Decision**: Use Ansible's built-in `wait_for_connection` module at the start of the orchestrator play targeting `k3s_cluster` group. Any unreachable node causes immediate failure with Ansible's native error reporting.

**Rationale**: Ansible already handles this — if a host in the play's `hosts` list is unreachable, it fails by default. The `any_errors_fatal: true` directive ensures the entire play stops rather than continuing with remaining hosts.

**Alternatives considered**:
- Custom pre-check with `ping` module → Unnecessary, Ansible's gather_facts achieves this.
- `ignore_unreachable: false` (default) → This is already the default behavior; just need `any_errors_fatal: true`.
