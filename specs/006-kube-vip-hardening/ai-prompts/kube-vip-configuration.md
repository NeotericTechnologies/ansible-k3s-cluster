The purpose of this iteration is to enhance and harden the Kube-VIP configuration and deployment.

Goals:
- Primary - Configure Kube-VIP as an egress controller for the cluster, making it easier to manage firewall rules associated with the cluster.
  - References:
    - https://kube-vip.io/docs/usage/egress/
- Primary - Enable service election, to allow kube-vip to automatically elect a leader when deploying in HA mode.
  - References:
    - https://kube-vip.io/docs/usage/kubernetes-services/#load-balancing-load-balancers-when-using-arp-mode-yes-you-read-that-correctly-kube-vip-v050
- Primary - Configure DHCP for the Kube-VIP load balancer(s).
  - References:
    - https://kube-vip.io/docs/usage/kubernetes-services/#using-dhcp-for-load-balancers-experimental-kube-vip-v021
- Review and update the RBAC bindings as needed to ensure Kube-VIP has the permissions it needs to function as expected.  A pervious commits titled `Generated fixes for Kube-VIP` was necessary to fix RBAC issues with Kube-VIP.  We want to ensure we don't run into similar issues in the future.

Source Code:
 - https://github.com/kube-vip/kube-vip
 - https://github.com/kube-vip/kube-vip-cloud-provider

The references provided for each feature are provided simply as a starting point for research and implementation details.  The source code would be the definitive source of information with respect to each feature.

Automated tests should be generated, where feasable, to:
- Validate egress controller configuration and operation.
- Validate service election is functioning as expected.
- Validate DHCP request configuration and observed assignment behavior.
- Validate RBAC bindings are correctly configured.
