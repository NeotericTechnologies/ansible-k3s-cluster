## Kube-VIP
- Install Kube-VIP as DaemonSet

## K3S Compatibility
- Ensure ALL deployments are compatible with k3s - patch the configurations as needed to ensure they are compatible.
- When working out k3s compatibity for deployments, DO NOT:
    - use symlinks on nodes.
    - copy files on nodes.
    - Remove or change any of the default paths that K3S uses.

## Multus CNI Plugin
- Install Multus CNI plugin as DaemonSet
- Install using the offical helm chart
- Ensure host paths are updated as needed for k3s compatibility.
