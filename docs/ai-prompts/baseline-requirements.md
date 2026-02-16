I'm building an Ansible playbook for the sole purpose of managing the complete lifecycle of a k3s cluster.  The playbook MUST be able to deploy a new k3s cluster as well as update the configuration of an existing cluster.  The playbook MUST be able to add and remove both Control Plane and Worker nodes.

Embedded etcd will be used for High Availability.

cert-manager should be installed on the cluster and issuers for both Let's Encrypt Staging and Let's Encrypt Production should be configured.  These issuer's must use DNS challenge authentication.

multus should be installed on the cluster and configured to allow pods to be connected to various available VLANs on the network.

The synology-csi will be used to define storage classes and manage persistant volumes on the cluster.

Rancher will be used as the management console for the cluster.

rancher-monitoring should be configured.

Traefik should be used for the ingress controller.

The playbook should leverage https://github.com/k3s-io/k3s-ansible where possible.

The k3s Control Plane MUST be accessible via a load-balancer or VIP - such as kube-vip.

Services and applications on the cluster MUST be accessible through a service load-balancer so they can be uniquely addressable - such as kube-vip.
