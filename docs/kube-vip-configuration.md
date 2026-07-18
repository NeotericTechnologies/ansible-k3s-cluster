# Kube-VIP Egress Routing Reference

Ensure that egress rules and mappings propagate correctly to coordinate stable outbound network flows. This document outlines active policies, routing targets, and setup profiles for operators.

## Egress Architecture Configuration

Configure egress mappings via DaemonSet variables to enforce destination targeting:
```yaml
kube_vip_egress_enable: true
```

Kube-vip will utilize the loadbalancer IP allocated to the service as the source egress address. In order to distinguish local cluster CIDR scopes and bypass egress rewrites, `egress_podcidr` and `egress_servicecidr` are specified.

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
