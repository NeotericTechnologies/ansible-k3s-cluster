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
    - Network attachment definitions must support DHCP.

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
