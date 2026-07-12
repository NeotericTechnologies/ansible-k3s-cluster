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

## 2) Validate default managed egress behavior

1. Enable managed egress configuration in inventory/group vars.
2. Apply the preferred unified lifecycle playbook:

```bash
ansible-playbook -i <inventory> ansible/playbooks/site.yml
```

3. Launch a validation workload without opt-out configuration and verify outbound source behavior.

Expected outcome:
- Workload uses managed egress identity by default.

## 3) Validate explicit opt-out and invalid opt-out fail-safe

1. Configure one workload with valid explicit opt-out.
2. Configure another workload with intentionally invalid/conflicting opt-out.
3. Re-apply the unified lifecycle playbook.

Expected outcome:
- Valid opt-out workload uses standard egress.
- Invalid opt-out workload remains on managed egress.
- Warning diagnostics are emitted for invalid opt-out.

## 4) Validate service election quorum-loss behavior

1. Ensure HA topology and service election are enabled.
2. Create a representative LoadBalancer service.
3. Introduce a controlled quorum-loss condition in a test window.

Expected outcome:
- Existing healthy service leadership remains active.
- New leadership changes are blocked while quorum is unavailable.
- Operational status reports degraded election state.
- Normal election behavior resumes when quorum is restored.

## 5) Validate DHCP allocation and retry path

1. Enable DHCP allocation mode.
2. Create a new LoadBalancer service and observe assignment lifecycle.
3. During a test window, make DHCP temporarily unavailable and observe status.

Expected outcome:
- Service remains in pending allocation during outage with automatic retries.
- Service transitions to allocated once DHCP becomes available.

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
- election degraded/healthy transition evidence
- DHCP pending-to-allocated transition evidence
- RBAC baseline reconciliation evidence

## 8) Completion criteria

The feature is validated when all scenarios above pass and observed behavior matches contracts in:
- `contracts/kube-vip-lifecycle-contracts.md`
- `data-model.md`
