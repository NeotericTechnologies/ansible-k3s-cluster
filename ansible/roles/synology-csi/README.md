# Synology CSI Role

Deploys the Synology CSI driver for persistent storage on k3s clusters, with optional NFS sub-directory provisioning via [kubernetes-csi/csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs).

## Components

| Component | Description |
|-----------|-------------|
| Synology CSI (`csi.san.synology.com`) | iSCSI and NFS volumes provisioned directly by the Synology DSM API |
| csi-driver-nfs (`nfs.csi.k8s.io`) | Sub-directory provisioning within a pre-existing NFS share (via Helm) |

## Requirements

- k3s cluster with `kubernetes.core` Ansible collection available
- Synology NAS with DSM 7.x, HTTPS API enabled on port 8443
- For csi-driver-nfs: a pre-existing NFS shared folder exported from the Synology NAS

## Variables

### Synology CSI (main driver)

| Variable | Default | Description |
|----------|---------|-------------|
| `synology_csi_enabled` | `false` | Enable Synology CSI deployment |
| `synology_csi_version` | `v1.2.1` | CSI driver image tag |
| `synology_csi_namespace` | `synology-csi` | Namespace for CSI components |
| `synology_csi_endpoint` | `""` | NAS management endpoint (FQDN or IP) |
| `synology_csi_port` | `8443` | HTTPS API port |
| `synology_csi_tls_verify` | `false` | Verify TLS certificate |
| `synology_csi_username` | `""` | DSM credentials (use Ansible Vault) |
| `synology_csi_password` | `""` | DSM credentials (use Ansible Vault) |
| `synology_csi_snapshots_enabled` | `false` | Deploy snapshot controller and CRDs |
| `synology_csi_storage_classes` | *(see below)* | List of StorageClass definitions |

#### `synology_csi_storage_classes` entries

```yaml
synology_csi_storage_classes:
  - name: "synology-iscsi-retain"
    protocol: "iscsi"          # "iscsi" or "nfs"
    is_default: true           # At most one default across all classes
    reclaim_policy: "Retain"   # "Retain" or "Delete"
    volume_binding_mode: "Immediate"  # "Immediate" or "WaitForFirstConsumer"
    parameters:
      fsType: "ext4"           # iSCSI only
      location: "/volume1"     # DSM volume root path
  - name: "synology-nfs-retain"
    protocol: "nfs"
    is_default: false
    reclaim_policy: "Retain"
    volume_binding_mode: "Immediate"
    parameters:
      location: "/volume1"
```

### csi-driver-nfs (NFS sub-directory provisioning)

| Variable | Default | Description |
|----------|---------|-------------|
| `csi_nfs_enabled` | `false` | Enable csi-driver-nfs deployment |
| `csi_nfs_version` | `v4.13.2` | Helm chart version |
| `csi_nfs_storage_classes` | *(see below)* | List of NFS sub-directory StorageClass definitions |

#### `csi_nfs_storage_classes` entries

Each entry creates a StorageClass that provisions PVCs as sub-directories within a pre-existing NFS share:

```yaml
csi_nfs_storage_classes:
  - name: "nfs-subdir"                # StorageClass name
    server: "{{ synology_csi_endpoint }}"  # NFS server address
    share: "/volume1/k8s-nfs"         # NFS export path (must already exist)
    is_default: false                  # Default StorageClass annotation
    reclaim_policy: "Retain"          # "Retain" or "Delete"
    volume_binding_mode: "Immediate"  # "Immediate" or "WaitForFirstConsumer"
    sub_dir: "${pvc.metadata.namespace}/${pvc.metadata.name}"  # Sub-directory template
    on_delete: "retain"               # "retain" or "delete" — action on PV deletion
    mount_options:                     # NFS mount options
      - hard
      - nfsvers=4.1
```

**Multiple StorageClasses example** (different shares or policies):

```yaml
csi_nfs_storage_classes:
  - name: "nfs-subdir-retain"
    server: "nas.example.com"
    share: "/volume1/k8s-persistent"
    reclaim_policy: "Retain"
    volume_binding_mode: "Immediate"
    sub_dir: "${pvc.metadata.namespace}/${pvc.metadata.name}"
    on_delete: "retain"
  - name: "nfs-subdir-delete"
    server: "nas.example.com"
    share: "/volume1/k8s-scratch"
    reclaim_policy: "Delete"
    volume_binding_mode: "Immediate"
    sub_dir: "${pvc.metadata.namespace}/${pvc.metadata.name}"
    on_delete: "delete"
```

## Usage

Enable in your inventory group vars:

```yaml
# group_vars/all.yml or host_vars
synology_csi_enabled: true
synology_csi_endpoint: "nas.example.com"
synology_csi_username: "k8s-csi"
synology_csi_password: "{{ vault_synology_password }}"

# Optional: NFS sub-directory provisioning
csi_nfs_enabled: true
csi_nfs_storage_classes:
  - name: "nfs-subdir"
    server: "nas.example.com"
    share: "/volume1/k8s-nfs"
    reclaim_policy: "Retain"
    volume_binding_mode: "Immediate"
```

Deploy via the cluster-addons playbook:

```bash
ansible-playbook -i <inventory> ansible/playbooks/cluster-addons.yml --tags storage
```

## Verification

```bash
# Synology CSI pods
kubectl -n synology-csi get pods

# StorageClasses (Synology + csi-driver-nfs)
kubectl get storageclass

# CSI drivers registered
kubectl get csidrivers

# Test PVC creation with NFS sub-directory
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-subdir
spec:
  accessModes: [ReadWriteMany]
  storageClassName: nfs-subdir
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc test-nfs-subdir
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ synology-csi role                                       │
├─────────────────────────────────────────────────────────┤
│ tasks/main.yml                                          │
│   ├── install.yml (when: synology_csi_enabled)          │
│   │     └─ namespace, RBAC, secrets, DaemonSet,         │
│   │        controller, snapshotter, StorageClasses      │
│   └── csi-driver-nfs.yml (when: csi_nfs_enabled)       │
│         └─ Helm repo, chart deploy, wait,               │
│            NFS sub-directory StorageClasses              │
├─────────────────────────────────────────────────────────┤
│ templates/                                              │
│   ├── storageclass-iscsi.yaml.j2    (loop: protocol=iscsi)  │
│   ├── storageclass-nfs.yaml.j2      (loop: protocol=nfs)    │
│   ├── storageclass-nfs-subdir.yaml.j2 (loop: csi_nfs_storage_classes) │
│   ├── csi-driver-nfs-values.yaml.j2 (Helm values)      │
│   └── ... (namespace, secrets, controller, etc.)        │
└─────────────────────────────────────────────────────────┘
```

## Tags

| Tag | Scope |
|-----|-------|
| `install` | All installation tasks |
| `storage` | All storage-related tasks |
| `csi-nfs` | csi-driver-nfs tasks only |
