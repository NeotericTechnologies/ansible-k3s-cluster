# Kube-VIP Egress Routing Reference

Ensure that egress rules and mappings propagate correctly to coordinate stable outbound network flows. This document outlines active policies, routing targets, and setup profiles for operators.

## Egress Architecture Configuration

Configure egress mappings via DaemonSet variables to enforce destination targeting:
```yaml
kube_vip_egress_enable: true
kube_vip_egress_destination: "10.0.0.0/8" # Target specific RFC1918 traffic
kube_vip_egress_source: "192.168.1.150"  # Target static egress pool allocation
```

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
