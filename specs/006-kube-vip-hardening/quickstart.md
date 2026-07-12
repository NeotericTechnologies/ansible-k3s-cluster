# Quickstart: Validate Kube-VIP Hardening

This guide validates managed egress, service election resilience, DHCP load balancer allocation, and RBAC baseline enforcement for the kube-vip hardening feature.

## Prerequisites

- Access to a target inventory with kube-vip enabled.
- k3s control plane reachable via kubectl context used by repository playbooks.
- DHCP service available for the target LoadBalancer network segment (for DHCP scenarios).
- Feature spec and contracts available:
  - `specs/006-kube-vip-hardening/spec.md`
  - `specs/006-kube-vip-hardening/contracts/kube-vip-lifecycle-contracts.md`
  - `specs/006-kube-vip-hardening/data-model.md`

## 1) Baseline dry-run checks

Run check mode using the preferred unified lifecycle entrypoint:

```bash
ansible-playbook --check -i <inventory> ansible/playbooks/site.yml
```

Targeted alternatives are retained for scoped operations:

```bash
ansible-playbook --check -i <inventory> ansible/playbooks/cluster-core.yml
ansible-playbook --check -i <inventory> ansible/playbooks/cluster-addons.yml
```

Expected outcome:
- No syntax/lint-level failures tied to kube-vip hardening variables.

## 2) Validate kube-vip egress prerequisites

1. Enable kube-vip egress configuration in inventory/group vars.
2. Apply the preferred unified lifecycle playbook:

```bash
ansible-playbook -i <inventory> ansible/playbooks/site.yml
```

3. Create or update a LoadBalancer Service that is not annotated with `kube-vip.io/ignore: "true"` and includes:

```yaml
metadata:
  annotations: {}
spec:
  externalTrafficPolicy: Local
```

4. Verify the kube-vip daemonset contains `svc_election`, `egress_podcidr`, and `egress_servicecidr` env settings.

Expected outcome:
- kube-vip runtime prerequisites for egress are present.
- Eligible non-opted-out Services use kube-vip egress handling by default when shaped with `externalTrafficPolicy: Local`.

## 3) Validate explicit kube-vip Service ignore behavior

1. Configure one Service with `kube-vip.io/ignore: "true"`.
2. Re-apply the unified lifecycle playbook.

Expected outcome:
- Explicit kube-vip service opt-out is preserved through the ignore annotation.

## 4) Validate service election runtime configuration

1. Ensure HA topology and service election are enabled.
2. Create a representative LoadBalancer service.

Expected outcome:
- `svc_election=true` is configured in the kube-vip daemonset.
- A LoadBalancer Service with `externalTrafficPolicy: Local` can be used for live service failover validation.

## 5) Validate DHCP allocation request path

1. Enable DHCP allocation mode.
2. Create a new LoadBalancer service and observe assignment lifecycle.

Expected outcome:
- Service requests DHCP using `loadBalancerIP: 0.0.0.0` or `kube-vip.io/loadbalancerIPs`.
- kube-vip daemonset exposes the configured `dhcp_mode`.
- Observed address assignment outcomes are captured in live validation evidence when DHCP infrastructure is available.

## 6) Validate RBAC baseline enforcement and reconciliation

1. Deploy with baseline enforcement enabled.
2. Introduce controlled RBAC drift (remove one required permission in test environment).
3. Re-run lifecycle playbook.

Expected outcome:
- Drift is detected and reconciled, or run fails with clear diagnostic if reconciliation cannot be completed.
- Final RBAC state is least-privilege and in sync with baseline.

## 7) Validation commands and evidence capture

Recommended checks:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip
kubectl get svc -A | grep LoadBalancer
kubectl auth can-i --as=system:serviceaccount:kube-system:kube-vip list services
```

Capture:
- egress behavior verification evidence
- service-election readiness or failover evidence
- DHCP pending-to-allocated transition evidence
- RBAC baseline reconciliation evidence

## 8) Automated validation execution (where feasible)

Run both lifecycle paths through the preferred entrypoint and feature-specific scenario runners.

```bash
ansible-playbook --check -i <inventory> ansible/playbooks/site.yml
ansible-playbook -i <inventory> ansible/playbooks/site.yml

ansible-playbook -i <inventory> tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml
ansible-playbook -i <inventory> tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml
```

Expected outcome:
- Automated validation covers egress behavior.
- Automated validation covers service election behavior.
- Automated validation covers DHCP request behavior.
- Automated validation covers RBAC binding correctness.
- Evidence includes at least one fresh-deploy path and one upgrade-path run.

## 9) Feasibility exceptions and manual fallback execution

Use fallback only when the environment cannot safely automate disruptive live failover or DHCP infrastructure conditions.

Manual fallback rules:

1. Record the reason automation is infeasible.
2. Execute the equivalent scenario manually.
3. Capture the same evidence fields expected from automated runs.

Recommended fallback evidence set:

- `kubectl -n kube-system get daemonset kube-vip -o yaml`
- `kubectl -n default get service <test-service> -o yaml`
- `kubectl auth can-i --as=system:serviceaccount:kube-system:kube-vip list services`
- Playbook output containing warning/degraded/permission-diagnostics messages

## 10) Fresh-deploy and upgrade walkthrough checklist

Use this checklist to document an end-to-end validation pass.

| Path | Command | Expected Evidence |
|------|---------|-------------------|
| Fresh deploy | `ansible-playbook -i <inventory> tests/ansible/integration/kube_vip_hardening/run_fresh_deploy.yml` | Daemonset env wiring, Service annotation/request patterns, RBAC baseline checks |
| Upgrade path | `ansible-playbook -i <inventory> tests/ansible/integration/kube_vip_hardening/run_upgrade_path.yml` | Same evidence-based capability set validated post-upgrade reconciliation |

## 11) Completion criteria

The feature is validated when all scenarios above pass and observed behavior matches contracts in:
- `contracts/kube-vip-lifecycle-contracts.md`
- `data-model.md`
