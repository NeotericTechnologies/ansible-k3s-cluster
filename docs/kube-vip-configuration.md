# Kube-VIP Egress Routing Reference

Ensure that egress rules and mappings propagate correctly to coordinate stable outbound network flows. This document outlines active policies, routing targets, and setup profiles for operators.

## Egress Architecture Configuration

Unlike static egress controllers, kube-vip egress NAT mapping is configured at the Service level and managed through Ansible variables. To delegate a stable LoadBalancer IP as the outbound egress identity for workload pods, define service entries under `kube_vip_services` and re-run the core playbook.

### Variable-Driven Workload Service Configuration

Define services in `ansible/group_vars/all.yml`:

```yaml
kube_vip_services:
  - name: egress-enabled-service
    namespace: default
    egress_enabled: true
    external_traffic_policy: Local
    selector:
      app: your-workload-app
    ports:
      - name: traffic
        port: 80
        target_port: 80
```

When the kube-vip role runs, these definitions are rendered into Service manifests and applied automatically by `ansible/roles/kube-vip/tasks/install.yml`.

Apply changes by re-running:

```bash
ansible-playbook -i <inventory> ansible/playbooks/cluster-core.yml
```

### Global Controller Configuration

Configure egress features globally via Ansible variables:
```yaml
kube_vip_egress_enable: true
```

To enable cluster-wide interception with the preferred CNI-native path (Cilium):

```yaml
kube_vip_global_egress_enable: true
kube_vip_global_egress_mode: cni-native
kube_vip_global_egress_cni_provider: cilium
kube_vip_global_egress_egress_ip: "192.168.1.100"  # usually control_plane_vip
```

Opt-out is label-based:

```yaml
kube_vip_global_egress_opt_out_label_key: kube-vip.io/egress-opt-out
kube_vip_global_egress_opt_out_label_value: "true"
```

Any pod with label `kube-vip.io/egress-opt-out: "true"` is excluded from global interception.

When egress is enabled, service election is also enabled automatically in the kube-vip DaemonSet (`svc_election=true`). You do not need a separate manual toggle to satisfy this prerequisite for kube-vip egress behavior.

Kube-vip uses this setting to map `egress_podcidr` and `egress_servicecidr` in the DaemonSet. These values are automatically and dynamically retrieved from your live Kubernetes cluster's initialization config (`cluster-cidr` and `service-cluster-ip-range`), eliminating manual parameter configuration errors and preventing outbound routing rewrites when communicating with internal resources.

## Network Policy Integration

Enforce egress traffic profiles across namespaces using standard Kubernetes network policies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: enforce-egress-path
  namespace: secure-workloads
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
```
