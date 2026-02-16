# Feature Specification: Baseline k3s Ansible Cluster Lifecycle

**Feature Branch**: `001-k3s-ansible-baseline`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "Baseline requirements for an Ansible playbook that manages the complete lifecycle of a k3s cluster, including deployment, configuration updates, node management, HA etcd, cert-manager with DNS challenges, multus VLAN networking, Rancher, rancher-monitoring, Traefik, use of k3s-ansible where possible, and load-balanced/VIP access via kube-vip."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision new HA k3s cluster (Priority: P1)

An operator wants to provision a new highly available k3s cluster on a set of prepared hosts by running a single Ansible playbook, resulting in a working cluster that uses embedded etcd, has the control plane exposed via a load balancer or VIP, and includes Traefik, cert-manager with both staging and production issuers using DNS challenges, multus for VLAN-based pod networking, Rancher, and rancher-monitoring.

**Why this priority**: This delivers the core value of the project: a repeatable, automated way to bring up a complete, production-ready k3s cluster with the required tooling and integrations.

**Independent Test**: Run the playbook against a clean inventory of eligible hosts and verify that a functional k3s cluster is created with all required components installed and accessible.

**Acceptance Scenarios**:

1. **Given** a set of hosts that meet the documented system prerequisites and are defined in the Ansible inventory with control-plane and worker roles, **When** the operator runs the playbook with default or minimal configuration, **Then** a new k3s cluster is created with embedded etcd, control-plane access via a load balancer or VIP, Traefik as ingress controller, cert-manager installed with both staging and production issuers using DNS challenges, multus configured for VLAN-based secondary interfaces, Rancher deployed as management console, and rancher-monitoring enabled.
2. **Given** the same inventory and configuration, **When** the operator re-runs the playbook without changes, **Then** the playbook completes successfully without error and without re-creating the cluster or disrupting workloads, confirming idempotent behavior.

---

### User Story 2 - Update existing cluster configuration (Priority: P2)

An operator needs to update configuration on an existing k3s cluster managed by this playbook (for example, adjusting cert-manager issuers, updating Rancher or Traefik configuration, or modifying multus VLAN network definitions) by re-running the playbook with updated variables, without rebuilding the cluster from scratch.

**Why this priority**: Ongoing configuration management is essential for maintaining and evolving the cluster safely over time without manual, error-prone changes.

**Independent Test**: Apply the playbook to an already-provisioned cluster after making specific configuration changes in group/host variables and verify that only the intended components are updated and the cluster remains healthy.

**Acceptance Scenarios**:

1. **Given** a running k3s cluster previously provisioned by this playbook, **When** the operator updates variables related to cert-manager issuers (such as DNS challenge details or contact email) and re-runs the playbook, **Then** the corresponding cert-manager resources are updated to match the new configuration without recreating the cluster.
2. **Given** a running k3s cluster and updated configuration for Rancher, rancher-monitoring, or Traefik in the variables, **When** the operator re-runs the playbook, **Then** the relevant components are updated to the new desired state while the rest of the cluster remains unchanged and available.

---

### User Story 3 - Manage control-plane and worker nodes (Priority: P3)

An operator wants to scale the cluster by adding or removing control-plane and worker nodes through inventory and variable changes, using the same playbook to join new nodes or safely remove existing ones while maintaining cluster health and, where applicable, embedded etcd quorum.

**Why this priority**: Cluster lifecycle management includes elasticity and maintenance of nodes; being able to manage node membership via Ansible is essential for long-term operations.

**Independent Test**: Start from a working cluster, then add and remove nodes via inventory and variables, applying the playbook each time and verifying that nodes are correctly joined or removed and the cluster remains functional.

**Acceptance Scenarios**:

1. **Given** a working k3s cluster with at least one control-plane node, **When** the operator adds additional control-plane and worker hosts to the inventory and re-runs the playbook, **Then** the new nodes join the cluster in the correct roles, appear in the cluster node list, and workloads can be scheduled on new workers.
2. **Given** a working HA cluster with multiple control-plane and worker nodes, **When** the operator marks specific nodes for removal in inventory or variables and runs the appropriate playbook flow, **Then** those nodes are gracefully drained and removed from the cluster, and control-plane and embedded etcd maintain quorum and availability according to documented guidelines.

---

### Edge Cases

- What happens when the playbook is run against hosts that do not meet the documented system prerequisites (e.g., unsupported OS, insufficient resources, missing network connectivity)? The playbook must fail fast with clear, actionable error messages without leaving the cluster in a partially configured or inconsistent state.
- How does the system handle partial failures during provisioning or upgrades (for example, if one node fails mid-run or cert-manager deployment fails while k3s is already installed)? The playbook must surface failures clearly, avoid rolling back healthy components unexpectedly, and allow safe re-runs after issues are corrected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The playbook MUST provision a new k3s cluster on a set of target hosts defined in the inventory, using embedded etcd for high availability where multiple control-plane nodes are defined.
- **FR-002**: The playbook MUST be idempotent and safe to re-run, converging existing clusters to the desired state without unnecessary restarts or data loss.
- **FR-003**: The playbook MUST support both deploying new clusters and updating configuration of existing clusters using the same entry point, based on inventory and variables.
- **FR-004**: The playbook MUST support adding and removing both control-plane and worker nodes via inventory and configuration changes, while preserving control-plane and embedded etcd quorum where applicable.
- **FR-005**: The playbook MUST install and configure cert-manager on the cluster, including issuers for both Let's Encrypt Staging and Let's Encrypt Production that use DNS challenge authentication.
- **FR-006**: The playbook MUST install and configure multus so that pods can be attached to additional network interfaces mapped to available VLANs on the underlying network, with configuration driven by variables.
- **FR-007**: The playbook MUST deploy Rancher as the management console for the k3s cluster and ensure that it is reachable via the configured ingress.
- **FR-008**: The playbook MUST deploy and configure rancher-monitoring to provide cluster and workload observability consistent with Rancher best practices.
- **FR-009**: The playbook MUST configure Traefik as the ingress controller for the cluster and ensure that services can be exposed via ingress resources.
- **FR-010**: The playbook MUST leverage the k3s-io/k3s-ansible project where practical, reusing roles or patterns provided there instead of duplicating logic, while still maintaining this project's specific requirements.
- **FR-011**: The k3s control plane MUST be accessible via a load balancer or virtual IP (for example, via kube-vip or an equivalent), and the playbook MUST configure or integrate with this mechanism via variables so that control-plane clients can use a single stable endpoint.
- **FR-012**: Services and applications on the cluster MUST be accessible through a service load-balancer mechanism (for example, via kube-vip or an equivalent) so that they can be uniquely addressable, and the playbook MUST provide configuration patterns and variables to enable this behavior.
- **FR-013**: The playbook MUST validate or enforce documented prerequisites on target hosts (such as supported OS, required packages, network connectivity, and firewall rules) and fail with clear messages when requirements are not met.
- **FR-014**: The playbook MUST provide clearly documented variables and example inventories for common scenarios, including at minimum a single-node cluster and a small HA cluster with multiple control-plane and worker nodes.

### Key Entities *(include if feature involves data)*

- **k3s Cluster**: A set of control-plane and worker nodes managed together, with configuration including k3s version, networking, storage, and control-plane access endpoint.
- **Cluster Node**: An individual host participating in the k3s cluster, characterized by its role (control-plane or worker), labels/taints, and connectivity to storage and networks.
- **Network Integration**: The configuration representing multus, VLAN attachments, and load-balancer/VIP endpoints for control-plane and services.
- **Cluster Add-ons**: Logical grouping of components such as cert-manager, Rancher, rancher-monitoring, Traefik, and related configuration and credentials.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can provision a new, fully functional k3s cluster with all required add-ons (cert-manager with staging and production issuers, multus, Rancher, rancher-monitoring, Traefik) in a single playbook run on supported infrastructure, with the end-to-end process typically completing within a time window acceptable for the target environment (for example, within one hour for a small HA cluster).
- **SC-002**: Re-running the playbook on an existing cluster results in successful completion with no unexpected disruptions to running workloads in at least 95% of test runs under normal conditions, demonstrating idempotent behavior.
- **SC-003**: Operators are able to successfully add or remove control-plane and worker nodes using the documented process in at least 90% of attempts during testing, without causing loss of cluster availability or etcd quorum for properly configured HA topologies.
- **SC-004**: At least 90% of target users (operators) report that the documented process for provisioning, updating, and scaling the cluster is understandable and can be followed without direct assistance after reading the documentation once, as measured by internal feedback or usability reviews.
