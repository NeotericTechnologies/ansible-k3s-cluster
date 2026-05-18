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

- **Decision**: Install Multus CNI as a DaemonSet using the official Helm chart (`https://k8snetworkplumbingwg.github.io/helm-charts`), with Helm values overriding host paths for k3s compatibility (CNI config dir, CNI bin dir). Configure secondary VLAN networks via `NetworkAttachmentDefinition` resources driven by variables. The base CNI remains the default chosen by k3s (flannel), with multus adding secondary interfaces.
- **Rationale**: The official Helm chart is the upstream-recommended installation method, provides structured configuration of volumes/paths via values, simplifies upgrades, and ensures DaemonSet deployment. Overriding host paths in Helm values (rather than post-deploy patching) is cleaner and idempotent. This keeps the base cluster simple while allowing operators to define VLAN mappings declaratively.
- **Alternatives Considered**:
  - **Raw manifest apply from GitHub**: Rejected because it requires post-deployment patching of volumes for k3s path compatibility and is harder to manage idempotently.
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

- **Decision**: Implement Synology CSI support as an optional role that is activated when Synology-specific variables are defined (e.g., storage endpoint, credentials). It will deploy the Synology CSI driver and a small set of opinionated StorageClasses.
- **Rationale**: Matches the clarification that Synology CSI is optional and keeps clusters without Synology storage compliant and simple.
- **Alternatives Considered**:
  - **Make Synology CSI mandatory**: Rejected; would make the playbook unusable in environments without Synology.

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
