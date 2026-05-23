# Implementation Plan: Baseline k3s Ansible Cluster Lifecycle

**Branch**: `001-k3s-ansible-baseline` | **Date**: 2026-05-23 | **Spec**: `specs/001-k3s-ansible-baseline/spec.md`

**Input**: Feature specification from `specs/001-k3s-ansible-baseline/spec.md`

## Summary

Ansible playbooks managing the complete lifecycle of a k3s cluster: provisioning with embedded etcd HA, node scaling, configuration updates, and minor/patch upgrades. Platform add-ons (kube-vip as DaemonSet, cert-manager with pluggable DNS-01, multus thick plugin via DaemonSet manifest, Rancher, rancher-monitoring, Traefik, optional Synology CSI with iSCSI/NFS/csi-driver-nfs sub-directory provisioning) are deployed as in-cluster resources via the Kubernetes API without node-level symlinks, file copies, or k3s path modifications.

## Technical Context

**Language/Version**: Ansible Core 2.15+ (YAML playbooks, Jinja2 templates)

**Primary Dependencies**: k3s (pinned version variable), kubernetes.core collection, community.kubernetes collection, Helm (for Rancher, rancher-monitoring, Traefik, cert-manager)

**Storage**: Synology CSI (optional) — iSCSI and NFS StorageClasses, NFS sub-directory provisioning via kubernetes-csi/csi-driver-nfs within pre-existing Synology NFS volumes

**Testing**: ansible-lint, ansible-playbook --check, smoke tests (idempotence, scale, upgrade, DNS provider switch, Synology PVC)

**Target Platform**: systemd-based Debian/Ubuntu Linux on x86_64 and arm64

**Project Type**: Infrastructure-as-Code / Ansible playbook collection

**Performance Goals**: Correctness, idempotence, and safe upgrades for small-to-medium on-prem clusters (1–3 control-plane, up to ~10 workers)

**Constraints**: No symlinks on nodes, no file copies to nodes for runtime workloads, no modification of default k3s paths, all add-ons deployed via Kubernetes API

**Scale/Scope**: Small-to-medium clusters; 1–3 control-plane nodes, up to ~10 worker nodes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Core cluster and add-ons are separate playbooks; add-ons are role-based and optional |
| II. Idempotent Cluster Provisioning | PASS | All roles use Ansible modules and kubernetes.core; safe to re-run |
| III. k3s-Specific Constraints | PASS | Version pinned, k3s flags honored, no kubeadm assumptions, DaemonSet deployments, no node filesystem manipulation |
| IV. Clear Inventory and Node Roles | PASS | k3s_servers / k3s_agents groups, host vars for labels/taints |
| V. Security, Networking, and Upgrades | PASS | TLS by default, no default credentials in repo, controlled upgrades via version variable |

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-ansible-baseline/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── lifecycle-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
ansible/
├── requirements.yml              # Galaxy collections/roles
├── group_vars/
│   ├── all.yml                   # Cluster-wide defaults
│   ├── k3s_servers.yml           # Server-specific vars
│   └── k3s_agents.yml            # Agent-specific vars
├── host_vars/                    # Per-host overrides
├── inventories/
│   ├── examples/
│   │   ├── ha-cluster/hosts.ini
│   │   └── single-node/hosts.ini
│   ├── production/
│   └── test-cluster/
├── playbooks/
│   ├── cluster-core.yml          # Core k3s provisioning
│   ├── cluster-addons.yml        # Platform add-ons
│   ├── scale-nodes.yml           # Node add/remove
│   └── upgrade-k3s.yml           # Minor/patch upgrades
└── roles/
    ├── k3s-common/               # Host prerequisites
    ├── k3s-server/               # Control-plane install
    ├── k3s-agent/                # Worker install
    ├── kube-vip/                 # VIP (DaemonSet)
    ├── cert-manager/             # Cert-manager + issuers
    ├── multus/                   # Multus thick plugin DaemonSet
    ├── traefik/                  # Ingress controller
    ├── rancher/                  # Rancher management
    ├── rancher-monitoring/       # Monitoring stack
    └── synology-csi/             # Synology CSI + csi-driver-nfs

tests/
└── ansible/
    ├── inventories/local
    └── smoke/
        ├── smoke.yml
        ├── idempotence-test.yml
        ├── scale-test.yml
        ├── upgrade-test.yml
        ├── dns-provider-switch-test.yml
        └── synology-pvc-test.yml
```
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
