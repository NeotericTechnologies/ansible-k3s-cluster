The purpose of this iteration is to add support for a load balanced egress gateway and to enhance the Kube-VIP configuration and deployment.

Primary Goals:
- Implement a load balanced egress gateway so all traffic exiting the cluster has a predictable IP address and associated hostname, making it easier to manage firewall rules associated with the cluster.

- Add support for enabling service election to allow Kube-VIP load balancers to automatically elect a leader when deploying in HA mode.

- Add support for enabling DHCP for the Kube-VIP load balancer(s).

- Update and consolidate the RBAC bindings to ensure Kube-VIP has the permissions it needs to function as expected.  A pervious commits titled `Generated fixes for Kube-VIP` was necessary to fix RBAC issues with Kube-VIP.  We want to ensure we don't run into similar issues in the future.
