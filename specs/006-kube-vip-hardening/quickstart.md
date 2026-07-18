# Quickstart: Kube-VIP Egress and HA Hardening

## Prerequisites
- Existing k3s inventory with at least one `k3s_servers` host.
- `kube-vip` role enabled in the cluster core playbook.
- `kubectl` access through `/etc/rancher/k3s/k3s.yaml` on the first server node.

## 1. Validate the plan inputs
Run the cluster core playbook in check mode first:

```bash
ansible-playbook -i ansible/inventories/test-cluster ansible/playbooks/cluster-core.yml --check
```

Expected outcome:
- kube-vip manifests render without template errors
- no missing variable failures
- no unsupported host or role assumptions

## 2. Validate kube-vip role behavior
Run the kube-vip role path against the test inventory:

```bash
ansible-playbook -i ansible/inventories/test-cluster ansible/playbooks/cluster-core.yml --tags kube-vip
```

Expected outcome:
- control-plane VIP manifest exists
- service controller manifest exists when LB mode is enabled
- RBAC objects are applied before runtime validation

## 3. Verify service election behavior
After deployment, confirm kube-vip uses service-election semantics for LoadBalancer handling:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip
kubectl -n kube-system get ds kube-vip
```

Expected outcome:
- kube-vip pods are running on control-plane nodes
- service election is enabled for managed LB services where required

## 4. Verify DHCP mode consistency
If DHCP mode is enabled for the environment, create or update multiple kube-vip-managed LoadBalancer services and confirm all of them receive DHCP-backed addresses using the same cluster-wide mode.

Example checks:

```bash
kubectl get svc -A | grep LoadBalancer
kubectl describe svc -n kube-system <service-name>
```

Expected outcome:
- services show `LoadBalancer` addresses assigned consistently
- no mixed static/DHCP behavior appears when DHCP is enabled

## 5. Verify RBAC hard-fail gate
Run the RBAC validation path used by the plan and confirm any missing permission blocks deployment.

Expected outcome:
- RBAC regression checks fail the rollout if permissions are incomplete
- no kube-vip authorization-denied errors appear in healthy deployments

## 6. Verify egress behavior
For workloads covered by kube-vip egress defaults, confirm outbound traffic uses the expected load-balancer egress path. For workloads with explicit opt-out, confirm default routing remains in place.

Expected outcome:
- default workloads use kube-vip egress
- opt-out workloads bypass kube-vip egress
- excluded CIDRs or ports behave as documented by kube-vip annotations

## Validation record
Store the result of each run in the deployment verification record for traceability.
