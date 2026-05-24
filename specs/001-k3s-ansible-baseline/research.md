# Phase 0 Research: Baseline k3s Ansible Cluster Lifecycle

## R-001: Minimum Supported Ansible Version

- **Decision**: Target Ansible Core 2.15+ as the minimum supported version for running the playbooks.
- **Rationale**: 2.15+ provides modern collections handling, stable YAML behavior, and current best practices for roles and inventories while still being widely available on common Linux distributions and via pip.
- **Alternatives Considered**:
  - **Older Ansible (e.g., 2.9)**: Rejected due to being EOL and lacking newer collection semantics; would constrain module usage and complicate future maintenance.
  - **Pinning to “latest” Ansible**: Rejected because it introduces variability in behavior between environments and conflicts with the constitution’s emphasis on controlled, predictable upgrades.

## R-002: Testing Approach (ansible-lint, check-mode, Molecule)

- **Decision**: Use `ansible-lint` and `ansible-playbook --check` as the mandatory baseline for this feature; Molecule tests are optional and may be introduced in a follow-up feature.
- **Rationale**: Linting and check-mode runs are lightweight, easy to integrate into CI, and directly support the constitution’s idempotence and quality gates without requiring complex local test harnesses. Molecule can add value later but is not strictly required to validate this baseline.
- **Alternatives Considered**:
  - **Mandatory Molecule for all roles**: Rejected for baseline due to increased setup complexity and time; not necessary to validate the initial structure and contracts.
  - **No structured testing (manual runs only)**: Rejected because it conflicts with the constitution’s requirement for quality gates and idempotence checks.

## R-003: Performance Goals and Constraints

- **Decision**: No strict numeric performance SLOs (e.g., cluster creation time, maximum node count) are defined for this baseline; the primary goal is correctness, idempotence, and safe upgrades for small-to-medium on-prem clusters.
- **Rationale**: The spec focuses on functional cluster lifecycle management and core add-ons, not on large-scale elasticity or rapid autoscaling. Over-constraining performance now would create unnecessary complexity without clear user requirements.
- **Alternatives Considered**:
  - **Hard SLOs (e.g., provision 20-node cluster in <30 minutes)**: Rejected due to lack of explicit requirement and high dependency on environment-specific factors (hardware, network).
  - **Unbounded expectations**: Rejected; documentation will state that the reference examples target small-to-medium clusters and that larger clusters may require additional tuning.

## R-004: Expected Cluster Scale and Scope

- **Decision**: Design and examples will target clusters with 1–3 control-plane nodes and up to a handful of worker nodes (for example, 1–10 workers), with the playbooks remaining structurally capable of handling more but without explicit guarantees.
- **Rationale**: This matches typical small HA clusters for homelab and small production environments and keeps the design simple while remaining useful.
- **Alternatives Considered**:
  - **Optimizing for very large clusters (dozens/hundreds of nodes)**: Rejected for baseline; such environments typically require additional operational tooling and constraints not covered by this feature.

## R-005: Use of k3s-io/k3s-ansible

- **Decision**: Treat `k3s-io/k3s-ansible` as an upstream reference and reuse its roles or tasks where they are stable and align with this spec (for example, host preparation and core k3s server/agent installation), pulling them in via Ansible collections/roles rather than copying code directly.
- **Rationale**: Reusing upstream logic reduces maintenance burden and aligns with community best practices, while keeping this repository focused on the additional integrations (cert-manager, multus, Rancher, monitoring, Traefik, Synology CSI, kube-vip).
- **Alternatives Considered**:
  - **Vendor/copy the entire k3s-ansible repo**: Rejected due to duplication and divergence risk.
  - **Ignore k3s-ansible entirely**: Rejected because it would forgo a well-known reference implementation and increase work for core cluster bootstrap.

## R-006: Embedded etcd HA Topology

- **Decision**: Use k3s embedded etcd for HA with 3 control-plane nodes as the primary documented pattern; support 1-node control-plane for non-HA scenarios as an explicit variant.
- **Rationale**: Embedded etcd is the recommended HA mode for k3s, and a 3-node control-plane is the standard pattern for quorum safety. Single-node control-plane is still useful for development/small setups.
- **Alternatives Considered**:
  - **External datastore (e.g., external etcd, SQL)**: Deferred; out of scope for this baseline to avoid added complexity.

## R-007: cert-manager DNS-01 Provider Abstraction

- **Decision**: Represent DNS providers via a `dns_provider` type and provider-specific credential variables (e.g., `cert_manager_dns_provider: cloudflare` plus a nested vars map). The playbooks will render different `ClusterIssuer` resources based on this configuration, without hard-coding a single provider.
- **Rationale**: Keeps the design aligned with the pluggable-provider clarification while allowing different environments (Cloudflare, Route53, etc.) without changing templates.
- **Alternatives Considered**:
  - **Hard-code a single provider (e.g., Cloudflare)**: Rejected; conflicts with clarification and reduces portability.

## R-008: multus VLAN Networking Pattern

- **Decision**: Install Multus CNI as a DaemonSet using the official thick plugin manifest (`deployments/multus-daemonset-thick.yml` from the upstream repository), applied via `kubernetes.core.k8s` with a Jinja2 template that adapts host paths for k3s compatibility (CNI config dir: `/var/lib/rancher/k3s/agent/etc/cni/net.d`, CNI bin dir: `/var/lib/rancher/k3s/data/current/bin`). Configure secondary VLAN networks via `NetworkAttachmentDefinition` resources driven by variables. The base CNI remains the default chosen by k3s (flannel), with multus adding secondary interfaces.
- **Rationale**: The upstream reference documentation (`https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs`) recommends deploying via `kubectl apply -f deployments/multus-daemonset-thick.yml`. Using the manifest directly (templated for k3s paths) follows the upstream guidance, avoids dependency on a third-party Helm chart, and gives full control over volume mounts and path overrides for k3s. The thick plugin is selected because it bundles all CNI functionality into a single daemon binary with a thin shim, reducing host-level file dependencies. Templating the manifest via Ansible/Jinja2 allows idempotent deployment via `kubernetes.core.k8s` with `state: present`.
- **Alternatives Considered**:
  - **Helm chart from k8snetworkplumbingwg**: Rejected because the upstream documentation recommends the manifest-based approach; the Helm chart is a community wrapper that may lag behind or diverge from the reference deployment.
  - **Thin plugin**: Rejected because it requires additional shim binaries on the host filesystem, which conflicts with the k3s compatibility constraint of minimizing node-level file operations.
  - **Replace the default CNI entirely with a more complex stack**: Rejected for baseline to avoid over-complicating network setup.

## R-009: Rancher and rancher-monitoring on k3s

- **Decision**: Deploy Rancher and rancher-monitoring via Helm charts managed by Ansible (using either the `kubernetes.core`/`community.kubernetes` modules or Helm-related modules), with configuration values driven from group vars and aligning with k3s/kube-vip ingress endpoints.
- **Rationale**: Helm is the standard deployment mechanism for Rancher and its monitoring stack; using Ansible to drive Helm values keeps configuration declarative and versionable.
- **Alternatives Considered**:
  - **Manual kubectl apply of manifests**: Rejected for baseline because it is harder to parameterize, test, and upgrade cleanly.

## R-010: kube-vip and Service Load Balancing

- **Decision**: Standardize kube-vip installation as a DaemonSet and model its configuration via variables for the control-plane VIP and service load-balancer addresses.
- **Rationale**: DaemonSet mode provides a clear operational model for node-local kube-vip pods and aligns with the updated planning directive to install kube-vip as DaemonSet while preserving variable-driven endpoint control.
- **Alternatives Considered**:
  - **Static pod mode for kube-vip**: Rejected for this baseline because the updated planning direction requires DaemonSet deployment.
  - **Rely solely on external, manually managed load balancers**: Rejected because it would reduce reproducibility and break the "single playbook" expectation.

## R-011: Synology CSI Integration

- **Decision**: Implement Synology CSI support as an optional role that is activated when Synology-specific variables are defined (e.g., storage endpoint, credentials). The deployment must include all required components: a dedicated namespace, client info secrets, a node DaemonSet (for volume attach/detach on nodes), a controller StatefulSet/Deployment (for provisioning), and a snapshotter controller. The role must support a configurable CSI driver version, iSCSI and NFS StorageClass templates, and VolumeSnapshot support. Connection to the Synology NAS uses HTTPS on port 8443 with self-signed certificate acceptance.
- **Rationale**: Matches the clarification that Synology CSI is optional and keeps clusters without Synology storage compliant and simple. The complete component set (namespace, secrets, DaemonSet, controller, snapshotter) is required by the Synology CSI driver architecture. HTTPS:8443 with self-signed certs is the standard DSM management port. Supporting both iSCSI and NFS storage classes covers the two common Synology volume access patterns.
- **Alternatives Considered**:
  - **Make Synology CSI mandatory**: Rejected; would make the playbook unusable in environments without Synology.
  - **iSCSI-only storage classes**: Rejected; NFS is a common access mode for shared volumes and read-write-many workloads.
  - **Require trusted certificates for NAS connection**: Rejected; most homelab/small-production Synology NAS units use self-signed certificates on port 8443, and requiring trusted certs adds unnecessary friction.

## R-014: NFS Sub-Directory Provisioning via csi-driver-nfs

- **Decision**: Deploy `kubernetes-csi/csi-driver-nfs` (CSI plugin name: `nfs.csi.k8s.io`, latest GA release v4.13.2) alongside the Synology CSI driver to support dynamic provisioning of NFS PersistentVolumes as sub-directories within a pre-existing Synology NFS volume. The driver is installed via its Helm chart managed by Ansible, and a dedicated StorageClass is created that references the Synology NFS server and an existing parent share path. Each PVC creates a new sub-directory under that share. Variables use the `csi_nfs_` prefix (e.g., `csi_nfs_enabled`, `csi_nfs_server`, `csi_nfs_share`, `csi_nfs_version`) to clearly identify their association with csi-driver-nfs.
- **Rationale**: The Synology CSI driver provisions new LUNs or new NFS volumes on the NAS per PVC. For use cases requiring many small volumes within a single pre-existing NFS export (e.g., application config, shared data directories), csi-driver-nfs provides lightweight sub-directory provisioning without creating new volumes on the NAS. This is the upstream Kubernetes SIG-Storage recommended approach for NFS sub-directory provisioning, is GA-stable, and compatible with k3s 1.21+.
- **Alternatives Considered**:
  - **nfs-subdir-external-provisioner (legacy)**: Rejected; superseded by csi-driver-nfs which is the official CSI-based replacement with broader feature support (snapshots, volume cloning).
  - **Synology CSI NFS provisioner only**: Insufficient; it creates new NFS volumes on the NAS per PVC rather than sub-directories within an existing volume.
  - **hostPath or local-path-provisioner**: Rejected; these are node-local and do not provide shared storage semantics.

## R-012: Inventory and Node Role Modeling

- **Decision**: Represent node roles via inventory groups such as `k3s_servers` (control-plane), `k3s_agents` (workers), and optional groups for infrastructure-related nodes if needed, with host-specific labels/taints defined in host vars.
- **Rationale**: Follows the constitution’s requirement for clear inventory and node roles, and aligns with typical Ansible practice and k3s-ansible patterns.
- **Alternatives Considered**:
  - **Role flags only in host vars without groups**: Rejected because it reduces clarity and makes targeting groups of nodes harder.
## R-013: k3s Deployment Compatibility Constraints

- **Decision**: All Kubernetes workload deployments managed by the playbooks (kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI) must be deployed in a manner compatible with k3s's opinionated runtime. Specifically, deployments MUST NOT:
  1. Create or rely on symlinks on cluster nodes.
  2. Copy files to cluster nodes outside of the Ansible provisioning flow.
  3. Remove or change any of the default paths that k3s uses (e.g., `/var/lib/rancher/k3s`, `/etc/rancher/k3s`, k3s data directories).
- **Rationale**: k3s uses a self-contained binary with specific path conventions. Modifying these paths or introducing symlinks/file copies breaks upgrade paths, confuses the k3s service manager, and creates drift between what k3s expects and what exists on disk. All add-ons should be deployed as in-cluster resources (Helm charts, manifests applied via kubectl/Ansible modules) rather than by manipulating the node filesystem.
- **Alternatives Considered**:
  - **Static pod manifests placed on disk**: Rejected because it requires file copies to nodes and conflicts with the no-file-copy constraint; DaemonSet deployments via the API are preferred (e.g., kube-vip as DaemonSet).
  - **Symlinked configuration directories**: Rejected because k3s manages its own paths and symlinks can interfere with k3s upgrades and the embedded containerd runtime.
  - **Modifying k3s default paths via flags**: Rejected because it deviates from documented k3s behavior and complicates troubleshooting and community support.

## R-015: Multus NetworkAttachmentDefinitions with DHCP Support

- **Decision**: NetworkAttachmentDefinitions for VLAN interfaces must support DHCP-based IP address assignment. The multus DHCP daemon runs as a DaemonSet pod on each node that listens on a UNIX socket (`/run/cni/dhcp.sock`) and proxies DHCP requests from pods to the external DHCP server on the attached VLAN network. The NAD configuration uses `"ipam": {"type": "dhcp"}` to delegate address assignment to the network's existing DHCP infrastructure.
- **Rationale**: VLAN networks in homelab and small-production environments typically have their own DHCP servers (e.g., on the router or a dedicated DHCP appliance). Requiring static IP assignment for every pod on a secondary network would be operationally burdensome and fragile. DHCP delegation allows pods to receive addresses from the same pool as other devices on the VLAN, enabling seamless integration with existing network infrastructure.
- **Alternatives Considered**:
  - **Static IPAM (host-local or whereabouts)**: Rejected as the primary mode because it requires manual CIDR management per network and does not integrate with existing DHCP infrastructure; however, static IPAM remains available as an alternative NAD configuration if users prefer it.
  - **No IPAM (manual IP assignment)**: Rejected; impractical for any non-trivial number of pods on secondary networks.

## R-016: DHCP Daemon DaemonSet Deployment — Avoiding Direct Binary Installation

- **Decision**: The CNI DHCP daemon DaemonSet must deploy the `dhcp` binary via an initContainer that downloads the official containernetworking/plugins release tarball from GitHub, extracts only the `dhcp` binary, and copies it to the k3s CNI bin directory (`/var/lib/rancher/k3s/data/current/bin`), rather than having Ansible download and install the binary directly on nodes during provisioning. The main container then runs the `dhcp daemon` command by referencing the binary at the host-mounted CNI bin path. This follows the same initContainer pattern used by the multus thick plugin DaemonSet for installing its own binaries.
- **Rationale**: The `docs/ai-prompts/plan.md` planning directive explicitly requires: "Deployed in such a way as to avoid installing the binary directly on the k3s node. If direct installation is required, installation utilizing an initContainer like the Multus Thick DaemonSet uses is acceptable." Using an initContainer keeps the binary lifecycle fully within Kubernetes (the DaemonSet manages it), avoids Ansible-time SSH file operations on nodes, and ensures the binary is automatically redeployed if the DaemonSet is recreated or a node is replaced. The tarball-from-GitHub-releases approach avoids dependency on any pre-built container image that may not exist upstream.
- **Architecture**:
  - **initContainer** (`install-cni-plugins`): Uses a minimal image (e.g., `alpine:3`) with shell and wget/curl. Downloads `https://github.com/containernetworking/plugins/releases/download/<version>/cni-plugins-linux-<arch>-<version>.tgz`, extracts only the `dhcp` binary via `tar xzf ... ./dhcp`, and copies it to the host CNI bin dir via a volume mount.
  - **initContainer** (`clean-dhcp-socket`): Removes stale UNIX socket at `/run/cni/dhcp.sock` before the daemon starts.
  - **Main container** (`dhcp-daemon`): Runs `dhcp daemon -hostprefix /host` using the host-mounted CNI bin dir binary. Uses `hostNetwork: true`, `privileged: true`, and mounts `/run/cni` (socket), `/proc` (host processes), `/run/netns` (network namespaces with HostToContainer propagation).
- **k3s Path Compatibility**:
  - CNI bin dir: `/var/lib/rancher/k3s/data/current/bin` (canonical path for this project)
  - Socket path: `/run/cni/dhcp.sock`
  - The DHCP daemon does NOT modify any default k3s paths — it only adds a binary to the CNI bin dir (which is the designated location for additional CNI plugins per k3s docs).
- **Implementation References**:
  - Primary: https://github.com/k8snetworkplumbingwg/reference-deployment/tree/master/multus-dhcp
  - RKE2 chart pattern: https://github.com/rancher/rke2-charts/blob/main-source/packages/rke2-multus/charts/templates/dhcp-daemonSet.yaml
  - k3s CNI paths: https://docs.k3s.io/networking/multus-ipams
  - CNI DHCP plugin docs: https://www.cni.dev/plugins/current/ipam/dhcp/
  - Additional references: https://github.com/k8snetworkplumbingwg/reference-deployment/pull/6, https://github.com/rancher/rke2/issues/3917
- **Alternatives Considered**:
  - **Ansible `get_url` + `tar` to install dhcp binary on host during provisioning**: Rejected because it violates the plan requirement to avoid installing binaries directly on k3s nodes via Ansible. Also creates a drift risk — the binary is not managed by Kubernetes and could become stale after node replacements or upgrades.
  - **Bundling dhcp binary in a custom Docker image and running it directly from the container (no host mount)**: Rejected because the CNI DHCP daemon must be reachable via a UNIX socket at `/run/cni/dhcp.sock` on the host, and the CNI plugin invocations happen outside the container namespace. The binary must be accessible at the host's CNI bin path.
  - **Using the multus container image to provide the dhcp binary**: Rejected because the multus thick image does not bundle the separate `dhcp` IPAM binary from `containernetworking/plugins`.
  - **Relying on k3s to bundle the dhcp binary**: Rejected because k3s does not include the `dhcp` binary in its CNI plugin bundle (it includes bridge, flannel, host-local, loopback, portmap, but NOT dhcp).
