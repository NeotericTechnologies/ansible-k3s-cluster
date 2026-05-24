# Multus CNI Role

Deploys [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) as a thick plugin DaemonSet on k3s, enabling pods to attach to multiple networks (e.g. VLAN-based secondary interfaces).

## Features

- Thick plugin DaemonSet (no file copies or symlinks on nodes)
- k3s-compatible path overrides for CNI conf/bin directories
- DHCP daemon DaemonSet for DHCP-based IPAM on secondary networks
- NetworkAttachmentDefinitions with DHCP, host-local, or static IPAM
- Idempotent convergence (safe to re-run)

## Requirements

- k3s cluster provisioned via `cluster-core.yml`
- For DHCP IPAM: a DHCP server reachable on the target VLAN

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `multus_enabled` | `false` | Enable/disable the entire multus role |
| `multus_namespace` | `kube-system` | Namespace for multus resources |
| `multus_image` | `ghcr.io/k8snetworkplumbingwg/multus-cni` | Container image for multus and DHCP daemon |
| `multus_version` | `v4.2.4-thick` | Image tag (thick plugin variant) |
| `multus_cni_conf_dir` | `/var/lib/rancher/k3s/agent/etc/cni/net.d` | k3s CNI config directory |
| `multus_cni_bin_dir` | `/var/lib/rancher/k3s/data/current/bin` | k3s CNI binary directory |
| `multus_log_level` | `error` | Multus log verbosity |
| `multus_dhcp_daemon_enabled` | `true` | Deploy DHCP daemon DaemonSet |
| `multus_vlan_networks` | `[]` | List of VLAN network definitions (see below) |

## VLAN Network Definitions

Each entry in `multus_vlan_networks` creates a `NetworkAttachmentDefinition`:

```yaml
multus_vlan_networks:
  - name: storage-vlan        # NAD resource name
    namespace: default        # Kubernetes namespace (default: default)
    interface: eth0           # Host interface for macvlan
    vlan_id: 100             # VLAN tag (optional, omit for untagged)
    ipam_type: dhcp          # dhcp | host-local | static (default: dhcp)
```

### IPAM Types

#### DHCP (default)

Delegates IP assignment to an existing DHCP server on the VLAN. Requires the DHCP daemon DaemonSet (`multus_dhcp_daemon_enabled: true`).

```yaml
multus_vlan_networks:
  - name: mgmt-net
    interface: eth0
    vlan_id: 10
    ipam_type: dhcp
```

**How it works**: The DHCP daemon runs on every node and proxies DHCP requests from pods to the external DHCP server on the attached VLAN. No additional pod-level configuration is needed.

#### Host-local

Assigns IPs from a node-local subnet range. Requires `cidr`; `gateway` is optional.

```yaml
multus_vlan_networks:
  - name: storage-net
    interface: eth0
    vlan_id: 100
    ipam_type: host-local
    cidr: 10.10.100.0/24
    gateway: 10.10.100.1
```

#### Static

Assigns a fixed IP address. Requires `cidr`; `gateway` is optional.

```yaml
multus_vlan_networks:
  - name: fixed-ip-net
    interface: eth1
    vlan_id: 200
    ipam_type: static
    cidr: 10.10.200.5/24
    gateway: 10.10.200.1
```

## DHCP Daemon

The DHCP daemon DaemonSet runs on all nodes with `hostNetwork: true` and privileged access. It listens on a UNIX socket for DHCP proxy requests from pods that use `"ipam": {"type": "dhcp"}` in their NetworkAttachmentDefinition.

### Enabling/Disabling

```yaml
# Enable (default) — deploys the DaemonSet
multus_dhcp_daemon_enabled: true

# Disable — removes the DaemonSet if previously deployed
multus_dhcp_daemon_enabled: false
```

Setting `multus_dhcp_daemon_enabled: false` and re-running the playbook will cleanly remove the DaemonSet. This is useful if all your VLAN networks use host-local or static IPAM.

### Prerequisites for DHCP

- A DHCP server must be reachable on the VLAN network
- The host interface (e.g. `eth0.100`) must be able to pass DHCP traffic
- VLAN interfaces should already exist on the host (typically configured outside this role)

## Usage

### Enable multus in group_vars

```yaml
# ansible/group_vars/all.yml (or inventory group_vars)
multus_enabled: true

multus_vlan_networks:
  - name: iot-vlan
    interface: eth0
    vlan_id: 50
    ipam_type: dhcp
  - name: storage-vlan
    interface: eth0
    vlan_id: 100
    ipam_type: host-local
    cidr: 10.10.100.0/24
    gateway: 10.10.100.1
```

### Deploy

```bash
ansible-playbook -i inventories/production ansible/playbooks/cluster-addons.yml
```

### Attach a pod to a secondary network

Add the `k8s.v1.cni.cncf.io/networks` annotation to your pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    k8s.v1.cni.cncf.io/networks: default/iot-vlan
spec:
  containers:
    - name: app
      image: my-app:latest
```

The pod will receive its primary interface from the default CNI (flannel) and a secondary interface (`net1`) attached to the specified VLAN with an IP assigned via the configured IPAM method.

### Verify

```bash
# Check multus DaemonSet
kubectl get ds -n kube-system kube-multus-ds

# Check DHCP daemon
kubectl get ds -n kube-system multus-dhcp-daemon

# List NetworkAttachmentDefinitions
kubectl get net-attach-def -A

# Check pod secondary interface
kubectl exec my-app -- ip addr show net1
```

## Smoke Test

A smoke test validates the DHCP daemon and DHCP-based NAD functionality:

```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/multus-dhcp-test.yml
```

This test verifies:
- DHCP daemon DaemonSet is running on all nodes
- At least one DHCP-type NetworkAttachmentDefinition exists
- A test pod receives a DHCP-assigned IP on its secondary interface
