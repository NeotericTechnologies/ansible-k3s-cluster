# Quickstart Validation Guide: Egress Gateway and Kube-VIP Enhancements

**Feature**: `006-egress-gateway-kube-vip`
**Date**: 2026-07-25
**Purpose**: Runnable validation scenarios that prove the feature works end-to-end.
**Not included**: Full implementation code, role bodies, migrations, or test suites. See `tasks.md` for those.

---

## Prerequisites

1. k3s cluster accessible via `kubectl` from the Ansible control node
2. Ansible inventory configured with `k3s_servers` and optionally `k3s_agents` groups
3. `ansible/requirements.yml` dependencies installed: `ansible-galaxy collection install -r ansible/requirements.yml`
4. For egress gateway validation: a static IP reserved for `kube_vip_egress_ip` outside DHCP/LB range
5. For DHCP validation: an external DHCP server reachable on the cluster node network
6. See [Ansible Variable Contracts](contracts/ansible-variable-contracts.md) for all required variables

---

## Scenario 1: Validate Consolidated RBAC (baseline, no feature flags)

**Purpose**: Confirm RBAC reconciles correctly on fresh and existing clusters.

```bash
# Apply kube-vip role only
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip

# Check for RBAC errors in kube-vip pods (expected: zero RBAC-denied lines)
kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip --tail=50 | grep -i "forbidden\|rbac\|denied"

# Check cloud-controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip-cloud-controller --tail=50 | grep -i "forbidden\|rbac\|denied"

# Verify single ClusterRole exists
kubectl get clusterrole kube-vip -o yaml | grep -c "apiGroups"  # should be > 0
kubectl get clusterrole kube-vip-cloud-controller 2>&1  # should return "not found" after consolidation

# Verify two ClusterRoleBindings both reference kube-vip ClusterRole
kubectl get clusterrolebinding kube-vip -o jsonpath='{.roleRef.name}'           # → kube-vip
kubectl get clusterrolebinding kube-vip-cloud-controller -o jsonpath='{.roleRef.name}'  # → kube-vip
```

**Expected**: Zero RBAC-denied log lines; single ClusterRole `kube-vip`; two ClusterRoleBindings both ref `kube-vip`.

**Idempotence check**:
```bash
# Second run must report zero changed tasks for RBAC
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip 2>&1 | grep "changed="  # expected: changed=0
```

---

## Scenario 2: Validate Service Election

**Purpose**: Confirm per-service leader election distributes VIPs across nodes and fails over correctly.

**Inventory variable required**:
```yaml
kube_vip_svc_election_enabled: true
```

```bash
# Apply with election enabled
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip

# Verify svc_election is set in DaemonSet
kubectl get daemonset kube-vip -n kube-system -o jsonpath='{.spec.template.spec.containers[0].env}' \
  | python3 -c "import json,sys; envs=json.load(sys.stdin); print([e for e in envs if e['name']=='svc_election'])"
# expected: [{'name': 'svc_election', 'value': 'true'}]

# Create a test LoadBalancer service
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: test-election-svc
  namespace: default
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: does-not-exist
EOF

# Wait for IP assignment (up to 30s)
kubectl get svc test-election-svc -w

# Verify exactly one node owns the lease (name matches a node)
kubectl get lease -n kube-system | grep plndr-svcs-lock

# Cleanup
kubectl delete svc test-election-svc
```

**Expected**: Service receives ExternalIP from configured pool; exactly one Lease in `kube-system` for service; no split-brain.

---

## Scenario 3: Validate DHCP for LoadBalancer Services

**Purpose**: Confirm DHCP mode assigns IP via network DHCP server.

**Inventory variables required**:
```yaml
kube_vip_lb_dhcp_enabled: true
kube_vip_lb_ip_range: ""  # must be empty — validated by playbook
```

**Network prerequisite**: DHCP server reachable from cluster nodes, configured to serve addresses on the cluster node subnet.

```bash
# Apply with DHCP enabled
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip

# Create a Service requesting DHCP address
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx-dhcp
spec:
  loadBalancerIP: "0.0.0.0"
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: does-not-exist
EOF

# Wait for DHCP assignment (may take 5-10s)
kubectl get svc nginx-dhcp -w

# ExternalIP should be non-zero, non-0.0.0.0 (assigned by DHCP)
kubectl get svc nginx-dhcp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Cleanup
kubectl delete svc nginx-dhcp
```

**Mutual exclusion validation**:
```bash
# Attempt to run with both DHCP and static range set — must fail
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip \
  -e "kube_vip_lb_dhcp_enabled=true kube_vip_lb_ip_range=192.168.1.200-192.168.1.220"
# expected: FAILED! → "kube_vip_lb_dhcp_enabled and kube_vip_lb_ip_range are mutually exclusive"
```

---

## Scenario 4: Validate Egress Gateway (Combined kube-vip + Cilium)

**Purpose**: Confirm outbound pod traffic exits through the configured egress VIP.

**Inventory variables required**:
```yaml
cilium_enabled: true
cilium_version: "v1.16.x"  # pin exact version
kube_vip_egress_enabled: true
kube_vip_egress_ip: "192.168.1.245"  # reserved IP outside LB pool
kube_vip_egress_hostname: "egress.cluster.local"
kube_vip_egress_gateway_node_selector:
  kubernetes.io/hostname: "server-node-1"  # node that will hold the VIP
kube_vip_egress_pod_selector:
  egress-gated: "true"
kube_vip_egress_namespace_selector: {}
```

```bash
# Step 1: Install Cilium (new role)
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags cilium

# Step 2: Verify Cilium pods running
kubectl get pods -n kube-system -l k8s-app=cilium

# Step 3: Apply kube-vip role with egress enabled
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip

# Step 4: Verify egress Service and CiliumEgressGatewayPolicy created
kubectl get svc -n kube-system egress-gateway-svc -o wide
kubectl get ciliumegressgatewaypolicy egress-gateway-policy -o yaml

# Step 5: Verify egress VIP is assigned
kubectl get svc -n kube-system egress-gateway-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# expected: 192.168.1.245

# Step 6: Deploy test pod with egress label
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: egress-test
  labels:
    egress-gated: "true"
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
EOF

# Step 7: Check outbound source IP (use external echo service)
kubectl exec egress-test -- curl -s https://ifconfig.me
# expected: 192.168.1.245 (the egress VIP)
# Note: requires cluster nodes to have outbound internet access for external echo service
# Alternative: use an in-network echo server on 192.168.1.0/24

# Step 8: Run smoke test
rtk ansible-playbook tests/ansible/smoke/egress-gateway-test.yml \
  -i ansible/inventories/test-cluster/hosts.ini

# Cleanup
kubectl delete pod egress-test
```

**HA failover validation** (requires ≥2 control-plane nodes):
```bash
# Identify current VIP-holding node
kubectl get svc -n kube-system egress-gateway-svc -o jsonpath='{.metadata.annotations.kube-vip\.io/vipHost}'

# Cordon and drain that node (simulate failure)
NODE=<vip-host-from-above>
kubectl cordon $NODE
# Wait ≤15s for VIP migration
sleep 15

# Verify VIP migrated (different node)
kubectl get svc -n kube-system egress-gateway-svc -o jsonpath='{.metadata.annotations.kube-vip\.io/vipHost}'
# expected: different node name

# Restore
kubectl uncordon $NODE
```

---

## Scenario 5: Validate Cilium Not Present Error

**Purpose**: Confirm playbook rejects egress gateway when Cilium is not installed.

```bash
# Attempt egress with Cilium disabled
rtk ansible-playbook ansible/playbooks/cluster-addons.yml \
  -i ansible/inventories/test-cluster/hosts.ini \
  --tags kube-vip \
  -e "kube_vip_egress_enabled=true cilium_enabled=false kube_vip_egress_ip=192.168.1.245 kube_vip_egress_gateway_node_selector={}"
# expected: FAILED! → "Cilium CNI required for egress gateway (cilium_enabled must be true)"
```

---

## References

- [Ansible Variable Contracts](contracts/ansible-variable-contracts.md)
- [Data Model](data-model.md)
- [kube-vip Egress docs](https://kube-vip.io/docs/usage/egress/)
- [kube-vip Service Election docs](https://kube-vip.io/docs/usage/kubernetes-services/#load-balancing-load-balancers-when-using-arp-mode-yes-you-read-that-correctly-kube-vip-v050)
- [kube-vip DHCP docs](https://kube-vip.io/docs/usage/kubernetes-services/#using-dhcp-for-load-balancers-experimental-kube-vip-v021)
- [Cilium Egress Gateway](https://cilium.io/use-cases/egress-gateway/)
