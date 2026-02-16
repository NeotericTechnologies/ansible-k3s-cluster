# ansible-k3s-cluster Constitution

## Core Principles

### I. Minimal, Focused Playbooks
The Ansible playbooks must do the bare minimum required to provision and operate a functional k3s cluster: prepare hosts, install k3s, join nodes, and apply essential configuration. Non-essential application deployment, monitoring, or extras belong in separate playbooks or roles and must not be mixed into the core cluster provisioning flow.

### II. Idempotent Cluster Provisioning
All tasks must be idempotent and safe to re-run. Playbooks must converge the cluster into the desired state without requiring manual cleanup, must use Ansible modules instead of raw shell where feasible, and must avoid destructive operations (e.g., node wipe, data loss) unless explicitly guarded by clear variables and confirmations.

### III. k3s-Specific Constraints (NON-NEGOTIABLE)
Playbooks must target k3s, not generic Kubernetes. k3s version must be explicitly pinned and configurable, system requirements for k3s (cgroups, kernel modules, ports, container runtime) must be enforced or validated, and server/agent node roles must be clearly defined. Changes must never assume full kubeadm semantics, must respect k3s-specific flags and datastore options, and must not silently perform in-place major k3s upgrades.

### IV. Clear Inventory and Node Roles
The inventory must clearly distinguish control-plane (server) and worker (agent) nodes, including any special-purpose nodes (e.g., etcd, ingress, storage) via groups or host variables. Playbooks must derive behavior strictly from inventory and variables, not from hard-coded hostnames or IPs, and must work for at least a single-node and a small multi-node cluster.

### V. Security, Networking, and Upgrades
Default configuration must be secure by default: minimal open ports, TLS enabled by k3s, and no default credentials committed to the repository. Networking assumptions (CNI, service CIDR, cluster CIDR, required ports) must be explicit and configurable. Upgrades to k3s or critical dependencies must be controlled via variables and documented procedures, with safe rollback or re-run behavior.

## Ansible & k3s Requirements

- Playbooks must be organized with a clear entry point (e.g., site.yml or cluster.yml), roles for host preparation and k3s installation, and group/host variables for cluster configuration.
- Supported environments (e.g., Debian/Ubuntu-like, systemd-based Linux on x86_64/arm64) must be explicitly documented, and tasks must fail fast with clear messages on unsupported platforms.
- k3s installation must:
	- Pin k3s version via a variable and avoid "latest" by default.
	- Explicitly configure server and agent services, including token and server URL.
	- Ensure required ports for k3s control-plane and CNI are open and not conflicting.
- Cluster configuration must expose variables for at least: cluster name, k3s version, node labels/taints (where applicable), CNI settings, and datastore backend (embedded SQLite vs external datastore) when supported.
- Playbooks must never store secrets in the repository; secret values must be provided via Ansible Vault, environment-specific vars, or external secret management.

## Development Workflow & Quality Gates

- All changes to core cluster playbooks and roles must maintain idempotence and be validated at least with `--check` mode or a local test inventory.
- Any change that affects k3s version, datastore, or networking must include a short, documented upgrade path in the repository (e.g., in docs or changelog).
- Linting (e.g., ansible-lint) and basic syntax checks must pass before merging changes to the main branch.
- Example inventories and variable files must remain runnable and minimal, demonstrating a small single-node and basic multi-node cluster setup.

## Governance

- This constitution governs the design and evolution of all Ansible playbooks and roles in this repository that manage k3s clusters and takes precedence over ad-hoc practices.
- Non-negotiable k3s constraints (version pinning, role separation, security defaults, and explicit networking assumptions) must be reviewed in every change touching cluster provisioning.
- Any amendment to these principles or requirements must be documented in version control with rationale, and must include notes on impact to existing clusters.

**Version**: 1.0.0 | **Ratified**: 2026-02-16 | **Last Amended**: 2026-02-16
