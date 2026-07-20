Plan:
- Implement a load balanced egress gateway:
  - Combine the capabilities of Kube-VIP Egress and Cilium Egress Gateway together to form a complete solution.
  - Use Cilium as the CNI when the egress gateway feature is enabled.
  - Ensure there are tests for this feature.

- Implement service election:
  - Is required for Kube-VIP Egress, so should be enabled automatically when the egress gateway feature is enabled.
  - Ensure there are tests for this feature.

- Support for enabling DHCP for the Kube-VIP load balancer(s)
  - Ensure the ansible configuration and DHCP networking prerequisites are clearly documented.
  - Ensure there are tests for this feature.

- Update and consolidate the RBAC bindings:
  - The ClusterRole for both the kube-vip and kube-vip-cloud-controller service accounts be should merged and updated as needed.
  - The consolidated Cluster role should then be used for the ClusterRoleBinding for both service accounts.

References:
- https://cilium.io/use-cases/egress-gateway/
- https://kube-vip.io/docs/usage/egress/
- https://kube-vip.io/docs/usage/kubernetes-services/#load-balancing-load-balancers-when-using-arp-mode-yes-you-read-that-correctly-kube-vip-v050
- https://kube-vip.io/docs/usage/kubernetes-services/#using-dhcp-for-load-balancers-experimental-kube-vip-v021
- https://github.com/kube-vip/kube-vip
- https://github.com/kube-vip/kube-vip-cloud-provider
- https://github.com/cilium/cilium
