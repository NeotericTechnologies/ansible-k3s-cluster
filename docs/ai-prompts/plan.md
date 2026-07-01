## Kube-VIP
- Install Kube-VIP as DaemonSet

## K3S Compatibility
- Ensure ALL deployments are compatible with k3s - patch the configurations as needed to ensure they are compatible.
- When working out k3s compatibility for deployments, DO NOT:
    - use symlinks on nodes.
    - copy files on nodes.
    - Remove or change any of the default paths that K3S uses.

## Multus CNI Plugin
- Install
    - As a DaemonSet
    - Using the Thick Plugin
    - Using the documentation here as a reference; https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs
- Configuration
    - Ensure host paths are added/updated as needed for k3s compatibility.
- Network attachment definitions must support DHCP, which requires the use of the CNI IPAM DHCP plugin.
  - The DHCP plugin:
    - Should be deployed as a DaemonSet.
    - Deployed in such a way as to avoid installing the binary directly on the k3s node.  If direct installation is required, installation utilizing an initContainer like the Multus Thick DaemonSet uses is acceptable.
  - DHCP plugin implementation references:
    - Primary reference - https://github.com/k8snetworkplumbingwg/reference-deployment/tree/master/multus-dhcp
    - https://github.com/VictorRobellini/reference-deployment/tree/master/multus-dhcp
    - https://github.com/k8snetworkplumbingwg/reference-deployment/pull/6
    - https://docs.k3s.io/networking/multus-ipams
    - https://www.cni.dev/plugins/current/ipam/dhcp/
    - https://github.com/rancher/rke2-charts/blob/main-source/packages/rke2-multus/charts/templates/dhcp-daemonSet.yaml
    - https://www.reddit.com/r/rancher/comments/ilzdp7/howto_set_up_k8s_or_k3s_so_pods_get_ip_from_lan/
    - https://github.com/rancher/rke2/issues/3917

## Synology CSI
- Ensure complete installation, including:
    - Namespace
    - Client info secrets
    - DaemonSet
    - Controller
    - Snapshotter
- Support:
    - Configuration of version
    - Snapshots
    - Templates for storage classes
      - iSCSI
      - NFS
        - Support provisioning NFS volumes in a pre-existing volume, using kubernetes-csi/csi-driver-nfs.
- Use https to connect to NAS
    - Port 8443
    - Certificates are self signed
