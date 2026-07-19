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

### Enable Service Election Globally

Setup variable inside `group_vars/all.yml` or default variables:
```yaml
kube_vip_service_election_enable: true
```

Verify service election variable applies successfully in pod environments:
```bash
kubectl -n kube-system describe pod -l app.kubernetes.io/name=kube-vip | grep svc_election
```

Expected outcome:
- kube-vip pods are running on control-plane nodes
- service election is enabled for managed LB services where required

## 4. Verify DHCP mode consistency
If DHCP mode is enabled for the environment, create or update multiple kube-vip-managed LoadBalancer services and confirm all of them receive DHCP-backed addresses using the same cluster-wide mode.

### Enable DHCP Load Balancer Allocations

Toggle variable inside `group_vars/all.yml` or defaults:
```yaml
kube_vip_dhcp_enable: true
```

Verify DHCP global CIDR is applied in target ConfigMap resource structures:
```bash
kubectl -n kube-system describe configmap kubevip | grep cidr-global
```

Verify Cloud Provider pod maps sentinel addressing:
```bash
kubectl -n kube-system describe deploy kube-vip-cloud-controller | grep 0.0.0.0/32
```

Example checks:

```bash
kubectl get svc -A | grep LoadBalancer
```

Expected outcome:
- services show `LoadBalancer` addresses assigned consistently
- no mixed static/DHCP behavior appears when DHCP is enabled

## 5. Verify RBAC hard-fail gate
Run the RBAC validation path used by the plan and confirm any missing permission blocks deployment.

### Auditing & Impersonation Diagnosis

If permission checks fail, inspect ClusterRoles configurations:
```bash
kubectl get clusterrole kube-vip -o yaml
```

Diagnose active permissions using ServiceAccount impersonation checks manually:
```bash
kubectl auth can-i update services --as=system:serviceaccount:kube-system:kube-vip
kubectl auth can-i create leases --as=system:serviceaccount:kube-system:kube-vip --namespace=kube-system
kubectl auth can-i update pods --as=system:serviceaccount:kube-system:kube-vip
```

Expected outcome:
- RBAC regression checks fail the rollout if permissions are incomplete
- no kube-vip authorization-denied errors appear in healthy deployments

## 6. Verify egress behavior
Verify egress routing and stable source address translation on active workloads.

Egress behavior is driven dynamically at the Service level through playbook-managed kube-vip Service definitions.

### Service Egress Activation & Configuration

To enable egress source address translation (SNAT) through kube-vip for workloads, define service entries under `kube_vip_services` in inventory variables and re-run the core playbook:

```yaml
kube_vip_services:
  - name: egress-authorized-workload
    namespace: secure-workloads
    egress_enabled: true
    external_traffic_policy: Local
    selector:
      app: secure-app
    ports:
      - name: https
        port: 443
        target_port: 8443
```

Apply changes:

```bash
ansible-playbook -i ansible/inventories/test-cluster ansible/playbooks/cluster-core.yml
```

Ensure egress defaults are enabled globally in `group_vars/all.yml`:
```yaml
kube_vip_egress_enable: true
```

Note: Enabling `kube_vip_egress_enable` automatically enforces `svc_election=true` in the rendered kube-vip DaemonSet, because service election is required for egress services.

### Egress Opt-Out and Validation Commands

To explicitly opt-out an entire namespace or specific workload pod from egress routing rules, configure `kube-vip.io/egress: "false"` on the relevant workload Service or namespace policy entry.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: billing-system
  annotations:
    kube-vip.io/egress: "false" # Opts-out entire namespace
```

Verify egress mapping and applied routes on active pods:
```bash
kubectl describe pod -n kube-system -l app.kubernetes.io/name=kube-vip
```

Expected outcome:
- default workloads use kube-vip egress
- opt-out workloads bypass kube-vip egress
- excluded CIDRs or ports behave as documented by kube-vip annotations

## Validation record
Store the result of each run in the deployment verification record for traceability.
