# Lifecycle Contracts: Kube-VIP Hardening

**Feature**: 006-kube-vip-hardening
**Date**: 2026-07-12

## Playbook Interface Contract

### Entry Points

Preferred execution path:

```bash
ansible-playbook -i <inventory> ansible/playbooks/site.yml
```

Targeted alternatives (retained):

```bash
ansible-playbook -i <inventory> ansible/playbooks/cluster-core.yml
ansible-playbook -i <inventory> ansible/playbooks/cluster-addons.yml
```

### Behavior Contract

| Condition | Behavior |
|-----------|----------|
| Managed egress enabled | kube-vip daemonset exposes documented egress prerequisites and eligible Services use kube-vip egress by default when shaped with `externalTrafficPolicy: Local` and not explicitly ignored |
| Service has `kube-vip.io/ignore=true` | kube-vip ignores that Service as an explicit opt-out from kube-vip processing |
| Service election enabled | kube-vip daemonset sets `svc_election=true` for per-Service leadership |
| DHCP-enabled service requested | Service requests DHCP via `loadBalancerIP: 0.0.0.0` or `kube-vip.io/loadbalancerIPs` and kube-vip runtime uses configured `dhcp_mode` |
| RBAC baseline drift detected | Baseline is reconciled during deploy/upgrade run or run fails with clear diagnostics |
| Fresh deploy and upgrade paths | Both enforce same RBAC baseline and networking behavior |

## Variables Contract

Required/updated feature variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `kube_vip_egress_enabled` | `true` | Enables kube-vip egress prerequisite wiring |
| `kube_vip_egress_internal` | `true` | Uses documented internal kube-vip egress path for non-opted-out Services that meet egress prerequisites |
| `kube_vip_egress_pod_cidr` | `{{ cluster_cidr }}` | Pod CIDR exposed to kube-vip for egress exclusions |
| `kube_vip_egress_service_cidr` | `{{ service_cidr }}` | Service CIDR exposed to kube-vip for egress exclusions |
| `kube_vip_service_election_enabled` | `true` | Enables kube-vip service election behavior |
| `kube_vip_dhcp_enabled` | `true` | Enables kube-vip DHCP request support for LoadBalancer services |
| `kube_vip_dhcp_mode` | `ipv4` | DHCP address family used by kube-vip runtime |
| `kube_vip_rbac_baseline_enforced` | `true` | Enforces consolidated least-privilege RBAC baseline |

## Output Contract

The run MUST emit operator-visible status for:

- egress runtime configuration state and annotation requirements
- service election runtime configuration state
- DHCP runtime configuration state and request requirements
- RBAC baseline result (`in_sync/reconciled/error`)

Example status section:

```text
Kube-VIP Status:
  Egress: enabled (service annotations + Local externalTrafficPolicy required)
  Election: enabled (svc_election=true)
  DHCP: enabled (ipv4 mode; request via 0.0.0.0 or kube-vip.io/loadbalancerIPs)
  RBAC: reconciled (baseline drift corrected)
```

## Error Contract

| Error Code | Message Pattern | Cause |
|------------|-----------------|-------|
| DHCP_REQUEST_PENDING | `Service <service> is awaiting DHCP-backed address assignment` | DHCP-backed Service request has not yet been assigned an address |
| RBAC_BASELINE_MISMATCH | `RBAC baseline drift detected for kube-vip components` | missing or altered required permissions |
| RBAC_RECONCILE_FAILED | `Unable to reconcile kube-vip RBAC baseline` | apply/reconcile failure |

## Idempotency Contract

| Scenario | Expected Result |
|----------|-----------------|
| Re-run with no desired changes | No unintended task changes; status remains stable |
| Re-run after DHCP-backed Service request | Service request definition remains stable while assignment is observed externally |
| Re-run after RBAC drift | Baseline reconciles to desired least-privilege state |

## Automated Validation Contract

The feature MUST include feasible automated validation coverage for:

- managed egress behavior
- service election behavior
- DHCP request behavior
- RBAC binding correctness

Coverage rules:

- At least one automated validation scenario MUST run on a fresh-deploy path.
- At least one automated validation scenario MUST run on an upgrade-path.
- Any capability that cannot be fully automated MUST include documented manual fallback validation in quickstart guidance with explicit feasibility rationale.

Canonical validation playbooks:

- `tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml`
- `tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml`

## Feasibility Exceptions and Manual Fallback Contract

Some runtime observations can be infeasible to automate in every environment (for example live service failover or environment-specific DHCP infrastructure behavior). When a scenario is infeasible in CI/lab automation, the following contract applies:

- The run MUST mark the scenario as `manual_fallback` with rationale.
- The run MUST provide operator-executable fallback steps in quickstart guidance.
- The run MUST capture equivalent evidence (command output, status snapshots, and observed transition timing).

Fallback evidence minimums:

- Service failover observation evidence when validating live service election behavior
- DHCP pending-to-allocated transition evidence after infrastructure restoration
- RBAC denial diagnostic output when reconcile cannot proceed automatically
