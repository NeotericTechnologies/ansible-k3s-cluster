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
| Managed egress enabled | All workloads use managed egress by default |
| Workload has valid explicit opt-out | Workload uses standard outbound behavior |
| Workload has invalid/conflicting opt-out | Managed egress remains active and warning is emitted |
| Election quorum available | Service leadership changes operate normally |
| Election quorum unavailable | Existing healthy leaders are held; new leadership changes blocked; status reported degraded |
| DHCP temporarily unavailable | Service lease remains pending with automatic retries |
| RBAC baseline drift detected | Baseline is reconciled during deploy/upgrade run or run fails with clear diagnostics |
| Fresh deploy and upgrade paths | Both enforce same RBAC baseline and networking behavior |

## Variables Contract

Required/updated feature variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `kube_vip_egress_enabled` | `true` | Enables managed egress control features |
| `kube_vip_egress_default_mode` | `managed` | Default egress mode when egress is enabled |
| `kube_vip_egress_opt_out_selector` | `""` | Workload selector expression for explicit opt-out |
| `kube_vip_service_election_enabled` | `true` | Enables kube-vip service election behavior |
| `kube_vip_dhcp_enabled` | `true` | Enables DHCP address allocation for LoadBalancer services |
| `kube_vip_rbac_baseline_enforced` | `true` | Enforces consolidated least-privilege RBAC baseline |

## Output Contract

The run MUST emit operator-visible status for:

- managed egress mode (`enabled/disabled/degraded`)
- service election mode (`healthy/degraded`, including quorum state)
- DHCP lease behavior (`pending/allocated/unavailable`)
- RBAC baseline result (`in_sync/reconciled/error`)

Example status section:

```text
Kube-VIP Status:
  Egress: enabled (default managed, explicit opt-out supported)
  Election: degraded (quorum unavailable, leadership changes blocked)
  DHCP: pending (automatic retry active)
  RBAC: reconciled (baseline drift corrected)
```

## Error Contract

| Error Code | Message Pattern | Cause |
|------------|-----------------|-------|
| EGRESS_OPTOUT_INVALID | `Invalid egress opt-out for <workload>; managed egress retained` | malformed/conflicting opt-out selector |
| ELECTION_QUORUM_LOST | `Service election quorum unavailable; leadership changes blocked` | quorum lost during election |
| DHCP_UNAVAILABLE_RETRY | `DHCP unavailable for <service>; retrying allocation` | transient DHCP failure |
| RBAC_BASELINE_MISMATCH | `RBAC baseline drift detected for kube-vip components` | missing or altered required permissions |
| RBAC_RECONCILE_FAILED | `Unable to reconcile kube-vip RBAC baseline` | apply/reconcile failure |

## Idempotency Contract

| Scenario | Expected Result |
|----------|-----------------|
| Re-run with no desired changes | No unintended task changes; status remains stable |
| Re-run after transient DHCP outage | Pending leases progress to allocated when DHCP recovers |
| Re-run after RBAC drift | Baseline reconciles to desired least-privilege state |

## Automated Validation Contract

The feature MUST include feasible automated validation coverage for:

- managed egress behavior
- service election behavior
- DHCP lease acquisition and renewal lifecycle
- RBAC binding correctness

Coverage rules:

- At least one automated validation scenario MUST run on a fresh-deploy path.
- At least one automated validation scenario MUST run on an upgrade-path.
- Any capability that cannot be fully automated MUST include documented manual fallback validation in quickstart guidance with explicit feasibility rationale.
