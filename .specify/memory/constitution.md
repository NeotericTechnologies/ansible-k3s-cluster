<!--
Sync Impact Report
- Version change: 1.1.0 -> 1.2.0
- Modified principles:
	- V. Security, Networking, and Upgrades -> V. Security, Networking, Upgrades, and Traceability
- Added sections:
	- Agent Token Optimization Rules
	- Content Generation Rules
- Removed sections:
	- None
- Templates requiring updates:
	- ✅ .specify/templates/plan-template.md
	- ✅ .specify/templates/spec-template.md
	- ✅ .specify/templates/tasks-template.md
	- ✅ .specify/templates/agent-file-template.md
	- ✅ .github/copilot-instructions.md
	- ✅ .github/agents/copilot-instructions.md
- Follow-up TODOs:
	- None
-->

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

### V. Security, Networking, Upgrades, and Traceability
Default configuration must be secure by default: minimal open ports, TLS enabled by k3s, and no default credentials committed to the repository. Networking assumptions (CNI, service CIDR, cluster CIDR, required ports) must be explicit and configurable. Upgrades to k3s or critical dependencies must be controlled via variables and documented procedures, with safe rollback or re-run behavior.

Every change that alters operational behavior MUST include traceable evidence in repository artifacts (tests, docs, release notes, or task records) that the change was validated against declared requirements.

## Ansible & k3s Requirements

- Playbooks must be organized with a clear entry point (e.g., site.yml or a dedicated core cluster playbook), roles for host preparation and k3s installation, and group/host variables for cluster configuration.
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

## Agent Token Optimization Rules

- All agents MUST always use the Caveman skill when available.
- All CLI commands MUST be routed through `rtk`.
- Source code operations MUST be routed through the `codebase-memory-mcp` CLI tools where those tools provide equivalent coverage.
- Agent default output mode MUST be silent.
- Agents MUST NOT narrate actions.
- Agents MUST NOT provide explanations unless explicitly requested.
- Agents MUST NOT disclose internal reasoning.
- File changes MUST be performed via diffs only.
- Agents MUST minimize token consumption while preserving correctness and safety.

## Content Generation Rules

- All generated content (documentation, plans, code, and comments) MUST be grounded in evidence-based sources and verifiable repository context.
- Outputs MUST distinguish confirmed facts from assumptions.
- Agents MUST NOT present unsupported claims as facts.
- Outputs MUST be based on directly observed code, documentation, validated requirements, or explicitly cited external references when repository evidence is insufficient.

## Governance

- This constitution governs the design and evolution of all Ansible playbooks and roles in this repository that manage k3s clusters and takes precedence over ad-hoc practices.
- Every change proposal, implementation plan, task list, and review must include a compliance check against applicable constitution sections.
- Amendment procedure: amendments MUST be proposed via version-controlled changes, include rationale and migration impact, and be approved through normal repository review before merge.
- Versioning policy: constitutional changes MUST follow semantic versioning; MAJOR for incompatible principle or governance changes, MINOR for new principles/sections or materially expanded guidance, PATCH for clarifications and non-semantic wording updates.
- Compliance review expectations: pull requests that modify cluster behavior, agent behavior, or generated content standards MUST explicitly state how each applicable principle is satisfied and provide evidence links.

**Version**: 1.2.0 | **Ratified**: 2026-05-16 | **Last Amended**: 2026-07-18
