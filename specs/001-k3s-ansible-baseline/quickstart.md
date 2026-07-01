# Quickstart: Baseline k3s Ansible Cluster Lifecycle

This quickstart explains how to use the Ansible playbooks to provision and manage a k3s cluster according to the baseline specification.

## 1. Prerequisites

- Control node with Ansible Core 2.15+ installed.
- SSH access from the control node to all target hosts.
- Target hosts running a supported Linux distribution (e.g., Debian/Ubuntu), systemd-based, x86_64 or arm64.
- Target hosts meeting documented resource and network prerequisites (for example: sufficient CPU/RAM for k3s and add-ons, required kernel modules, required ports open between nodes, and outbound internet/DNS access as described in the Ansible layout/prerequisites docs).
- Basic DNS in place for the control-plane VIP/hostname and any ingress hostnames (e.g., Rancher).

## 2. Clone the Repository

- Clone this repository onto the Ansible control node.

## 3. Define Inventory and Variables

- Copy an example inventory from `ansible/inventories/examples/` into your own directory.
- Populate the `k3s_servers` and `k3s_agents` groups with your hosts.
- Set cluster-level variables for:
  - Cluster name and k3s version.
  - Control-plane VIP and API port.
  - Cluster and service CIDRs.
  - kube-vip configuration for the control-plane VIP and service load balancer addresses, with kube-vip deployment mode set to DaemonSet.
  - Add-on configurations (cert-manager, multus VLANs, Rancher, rancher-monitoring, Traefik, optional Synology CSI, DNS provider).
  - Note: All add-ons are deployed as in-cluster resources (Helm/Kubernetes API). Multus uses the thick plugin. Kube-vip runs as a DaemonSet. No symlinks, file copies to nodes, or k3s path modifications are performed.

## 4. Provision a New HA Cluster

- Run the core cluster playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/cluster-core.yml`
- (Optional) Run the add-ons playbook to deploy platform add-ons:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/cluster-addons.yml`
- Verify:
  - `kubectl get nodes` shows all control-plane and worker nodes.
  - Control-plane is reachable via the VIP endpoint configured via kube-vip (or equivalent).
  - `kubectl -n kube-system get daemonset kube-vip` reports desired and ready pods for kube-vip.
  - If you ran the add-ons playbook, core add-ons (cert-manager, multus, Rancher, monitoring, Traefik) are deployed and healthy.

## 5. Update Cluster Configuration

- Modify your group/host variable files to reflect the new desired configuration (for example, DNS-01 provider settings, Rancher hostname, Traefik options, kube-vip VIP or address pool).
- Re-run the core cluster playbook and, if needed, the add-ons playbook:
  - Core: `ansible-playbook -i <your-inventory> ansible/playbooks/cluster-core.yml`
  - Add-ons: `ansible-playbook -i <your-inventory> ansible/playbooks/cluster-addons.yml`

## 6. Scale Nodes

- Add or remove hosts in the inventory groups and update host vars as necessary.
- Run the scale playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/scale-nodes.yml`

## 7. Perform a Minor/Patch k3s Upgrade

- Update the `k3s_version` variable to the desired compatible minor/patch (major upgrades are out of scope for this baseline feature).
- Run the upgrade playbook:
  - `ansible-playbook -i <your-inventory> -e k3s_version=<new-version> ansible/playbooks/upgrade-k3s.yml`
- Verify that control-plane nodes and agents report the new version and that the cluster remains available aside from expected rolling restarts.

## 8. Enable Optional Synology CSI

- Define Synology CSI variables:
  - `synology_csi_enabled: true`
  - `synology_csi_version`: Driver version/tag to deploy.
  - `synology_csi_namespace`: Namespace for CSI components (e.g., `synology-csi`).
  - `synology_csi_endpoint`: NAS management endpoint (FQDN or IP).
  - `synology_csi_port`: HTTPS port (default `8443`).
  - `synology_csi_tls_verify`: Set to `false` for self-signed certificates (default).
  - `synology_csi_username` / `synology_csi_password`: Credentials (via Ansible Vault).
  - `synology_csi_snapshots_enabled`: Set to `true` to deploy snapshotter.
  - `synology_csi_storage_classes`: List of StorageClass definitions (iSCSI and/or NFS via Synology CSI).
- (Optional) Enable NFS sub-directory provisioning via csi-driver-nfs:
  - `csi_nfs_enabled: true`
  - `csi_nfs_version`: csi-driver-nfs Helm chart version (e.g., `v4.13.2`).
  - `csi_nfs_storage_classes`: List of NFS sub-directory StorageClass definitions. Each entry:
    - `name`: StorageClass name (e.g., `nfs-subdir`)
    - `server`: NFS server address (defaults to `synology_csi_endpoint`)
    - `share`: Path of the pre-existing NFS share (e.g., `/volume1/k8s-nfs`)
    - `is_default`: Whether this is the default StorageClass (`true`/`false`)
    - `reclaim_policy`: `Retain` or `Delete`
    - `volume_binding_mode`: `Immediate` or `WaitForFirstConsumer`
    - `sub_dir`: Sub-directory naming template (default: `${pv.metadata.name}`)
    - `on_delete`: Action when PV is deleted — `retain` or `delete`
    - `mount_options`: NFS mount options list (default: `["hard", "nfsvers=4.1"]`)
- Run the add-ons playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/cluster-addons.yml`
- Verify:
  - `kubectl -n synology-csi get pods` shows node DaemonSet, controller, and (if enabled) snapshotter pods running.
  - `kubectl get storageclass` shows configured iSCSI and/or NFS StorageClasses.
  - (If snapshots enabled) `kubectl get volumesnapshotclass` shows the Synology snapshot class.
  - (If NFS sub-dir enabled) `kubectl get csidrivers` shows `nfs.csi.k8s.io` alongside the Synology CSI driver, and `kubectl get storageclass` includes the configured NFS sub-directory StorageClass(es).

## 9. Validation and Smoke Tests

- Run `ansible-lint` on the playbooks/roles.
- Use `ansible-playbook --check` for dry-run validation against non-production inventories.
