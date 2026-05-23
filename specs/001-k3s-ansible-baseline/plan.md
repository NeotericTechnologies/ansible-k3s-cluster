# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-23 | **Spec**: [spec.md](specs/001-k3s-ansible-baseline/spec.md)

**Input**: Feature specification from `/specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible-driven lifecycle management for k3s clusters covering provisioning (embedded etcd HA), configuration updates, node scaling, and minor/patch upgrades. The core cluster playbook handles k3s installation with kube-vip (DaemonSet) providing control-plane VIP and service load balancing. A separate add-ons playbook deploys optional platform components (cert-manager with pluggable DNS-01 providers, multus thick-plugin DaemonSet with DHCP-capable VLAN networking, Rancher, rancher-monitoring, Traefik, and optional Synology CSI with NFS sub-directory provisioning). All deployments are k3s-compatible: no symlinks, no file copies to nodes, no modification of default k3s paths.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s (pinned version), kubernetes.core collection, community.kubernetes collection, Helm (for Rancher, rancher-monitoring, Traefik, csi-driver-nfs)

**Storage**: Embedded etcd (cluster state); optional Synology CSI (iSCSI/NFS persistent volumes); optional csi-driver-nfs (NFS sub-directory provisioning)

**Testing**: ansible-lint, `ansible-playbook --check`, smoke tests via test inventories

**Target Platform**: systemd-based Debian/Ubuntu-family Linux on x86_64 and arm64

**Project Type**: Infrastructure-as-code / Ansible playbook collection

**Performance Goals**: Provision reference topology (3 CP + 3 workers) within 60 minutes; idempotent re-runs with no unnecessary restarts

**Constraints**: Small-to-medium clusters (1-3 CP, up to ~10 workers); no major k3s version upgrades; no symlinks/file copies/path modifications on nodes

**Scale/Scope**: 1-3 control-plane nodes, up to ~10 worker nodes; ~10 Ansible roles; 4 playbook entry points

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core cluster and add-ons are separate playbooks; add-ons are optional |
| II. Idempotent Cluster Provisioning | PASS | All roles use Ansible modules, state-based convergence, no destructive operations |
| III. k3s-Specific Constraints | PASS | Version pinned, k3s paths respected, kube-vip as DaemonSet (not static pod), multus as DaemonSet manifest |
| IV. Clear Inventory and Node Roles | PASS | `k3s_servers`/`k3s_agents` groups, host-level labels/taints in host_vars |
| V. Security, Networking, and Upgrades | PASS | No secrets in repo (Vault/external), explicit CIDRs, controlled upgrades via version variable |
| Ansible & k3s Requirements | PASS | Clear entry points, fail-fast on unsupported platforms, pinned k3s version, documented vars |
| Development Workflow & Quality Gates | PASS | ansible-lint + check-mode required, example inventories maintained |

**Gate Result**: PASS — proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-ansible-baseline/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── lifecycle-contracts.md  # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml              # Galaxy collection/role dependencies
├── group_vars/
│   ├── all.yml                   # Cluster-wide defaults (k3s_version, CIDRs, VIP)
│   ├── k3s_servers.yml           # Server-specific vars
│   └── k3s_agents.yml            # Agent-specific vars
├── host_vars/                    # Per-host overrides (labels, taints, IPs)
├── inventories/
│   ├── examples/
│   │   ├── ha-cluster/hosts.ini  # 3 CP + 3 worker reference
│   │   └── single-node/hosts.ini # Minimal single-node
│   ├── production/               # Real environment inventory
│   └── test-cluster/             # CI/smoke test inventory
├── playbooks/
│   ├── cluster-core.yml          # Core k3s + kube-vip provisioning
│   ├── cluster-addons.yml        # Optional add-on deployment
│   ├── scale-nodes.yml           # Add/remove nodes
│   └── upgrade-k3s.yml          # Minor/patch version upgrades
└── roles/
    ├── k3s-common/               # Shared prerequisites & dependencies
    ├── k3s-server/               # Control-plane installation
    ├── k3s-agent/                # Worker node installation
    ├── kube-vip/                 # DaemonSet VIP + service LB
    ├── cert-manager/             # cert-manager + DNS-01 issuers
    ├── multus/                   # Thick plugin DaemonSet + VLAN NADs
    ├── traefik/                  # Ingress controller
    ├── rancher/                  # Management UI
    ├── rancher-monitoring/       # Observability stack
    └── synology-csi/             # Optional Synology CSI + csi-driver-nfs

tests/
└── ansible/
    ├── inventories/local         # Local test inventory
    └── smoke/                    # Smoke test playbooks
```

**Structure Decision**: Single Ansible project at repository root. Roles encapsulate each logical concern. Playbooks are entry points that compose roles. No monorepo/multi-project complexity.

## Key Design Decisions (from docs/ai-prompts/plan.md updates)

### Kube-VIP
- Installed as a **DaemonSet** (not static pod)
- Provides both control-plane VIP and service load balancing
- Configuration via Ansible variables for VIP address, interface, and service LB address range

### K3S Compatibility (Cross-Cutting)
- ALL deployments must be compatible with k3s
- **MUST NOT**: use symlinks on nodes, copy files on nodes, remove/change default k3s paths
- Add-ons deployed via Kubernetes API (Helm charts, `kubernetes.core.k8s` manifests)

### Multus CNI Plugin
- Installed as a **DaemonSet** using the **Thick Plugin**
- Reference: https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs
- Host paths patched for k3s compatibility:
  - CNI config dir: `/var/lib/rancher/k3s/agent/etc/cni/net.d`
  - CNI bin dir: `/var/lib/rancher/k3s/data/current/bin`
- **NetworkAttachmentDefinitions must support DHCP** for VLAN interfaces
- Applied via `kubernetes.core.k8s` with Jinja2 template

### Synology CSI
- Complete installation including: Namespace, Client info secrets, DaemonSet, Controller, Snapshotter
- Configurable version
- Snapshot support (VolumeSnapshotClass + snapshotter controller)
- Storage class templates:
  - **iSCSI**: Block storage classes
  - **NFS**: File storage classes via Synology CSI driver
  - **NFS sub-directory**: Provisioning within pre-existing NFS volume using `kubernetes-csi/csi-driver-nfs`
- Connection: HTTPS port 8443, self-signed certificates accepted

## Complexity Tracking

No constitution violations requiring justification. Design remains within prescribed boundaries.
