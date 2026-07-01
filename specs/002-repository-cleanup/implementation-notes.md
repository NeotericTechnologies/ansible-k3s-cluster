# Implementation Notes: Repository Cleanup and Documentation Alignment

## Scope

This document tracks execution details for tasks T001-T044.

## Baseline Artifact Reference Scan Commands

- `grep -RIn "dns-provider-switch-test\|deprecated\|TODO\|hard-coded" ansible docs tests`
- `grep -RIn "ansible/playbooks\|ansible/roles\|tests/ansible/smoke\|specs/" README.md docs CONTRIBUTING.md ansible/roles`
- `grep -RIn "latest\|:3$\|:latest" ansible docs tests`

## Baseline Workflow Validation Command Matrix

- `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-core.yml --syntax-check`
- `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-addons.yml --syntax-check`
- `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/scale-nodes.yml --syntax-check`
- `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/upgrade-k3s.yml --syntax-check`
- `ansible-lint ansible/playbooks/cluster-core.yml ansible/playbooks/cluster-addons.yml ansible/playbooks/scale-nodes.yml ansible/playbooks/upgrade-k3s.yml`

## Repository Artifact Inventory

| Artifact Path | Kind | Status | Workflow Links | Planned Action | Rationale |
|---|---|---|---|---|---|
| tests/ansible/smoke/dns-provider-switch-test.yml | test | candidate-obsolete | smoke validation | remove | Not referenced by primary smoke suite; overlaps cert-manager behavior checks |
| tests/ansible/smoke/smoke.yml | test | active | smoke validation | update-if-needed | Maintain baseline smoke validation after cleanup |
| ansible/group_vars/all.yml | config | active | all lifecycle playbooks | update | Canonical version source for managed components |
| ansible/roles/cert-manager/defaults/main.yml | role default | active | cluster-addons cert-manager | update | Remove duplicate hard-coded version defaults |
| ansible/roles/kube-vip/defaults/main.yml | role default | active | cluster-core kube-vip | update | Remove duplicate hard-coded version defaults |
| ansible/roles/rancher/defaults/main.yml | role default | active | cluster-addons rancher | update | Remove duplicate hard-coded version defaults |
| README.md | doc | active | onboarding, operations | update | Align workflow, version, and validation guidance |
| docs/ansible-k3s-baseline.md | doc | active | lifecycle operations | update | Align docs to current repo structure and workflows |
| docs/ansible-structure.md | doc | active | structure and standards | update | Add version-source policy and current references |
| CONTRIBUTING.md | doc | active | contributor workflow | update | Add cleanup and version-centralization requirements |

## Workflow-to-Artifact Dependency Map

| Workflow | Entrypoint | Required Artifacts |
|---|---|---|
| Provision core cluster | ansible/playbooks/cluster-core.yml | ansible/group_vars/*.yml, roles/k3s-*, roles/kube-vip |
| Deploy add-ons | ansible/playbooks/cluster-addons.yml | ansible/group_vars/all.yml, roles/cert-manager, roles/multus, roles/rancher, roles/traefik, roles/synology-csi |
| Scale nodes | ansible/playbooks/scale-nodes.yml | ansible/group_vars/*.yml, roles/k3s-* |
| Upgrade k3s | ansible/playbooks/upgrade-k3s.yml | ansible/group_vars/all.yml (k3s_version), roles/k3s-* |
| Smoke validation | tests/ansible/smoke/smoke.yml | core cluster API reachability and kubectl |

## Documentation Topic Index

| Topic | Path | Audience | Validation State |
|---|---|---|---|
| Repository overview and quick start | README.md | contributor/operator | pending |
| Baseline lifecycle guide | docs/ansible-k3s-baseline.md | operator/maintainer | pending |
| Project structure and policy | docs/ansible-structure.md | contributor/maintainer | pending |
| Contributor standards | CONTRIBUTING.md | contributor | pending |
| Role usage: cert-manager | ansible/roles/cert-manager/README.md | maintainer | pending |
| Role usage: k3s-common | ansible/roles/k3s-common/README.md | maintainer | pending |
| Role usage: k3s-server | ansible/roles/k3s-server/README.md | maintainer | pending |
| Role usage: k3s-agent | ansible/roles/k3s-agent/README.md | maintainer | pending |

## Version Source Catalog

Canonical source location: `ansible/group_vars/all.yml`

| Variable | Current Value | Consumers |
|---|---|---|
| k3s_version | v1.28.5+k3s1 | k3s-server, k3s-agent, upgrade-k3s |
| kube_vip_version | v1.1.2 | kube-vip templates/tasks |
| kube_vip_cloud_provider_version | v0.0.12 | kube-vip cloud controller template |
| cert_manager_version | v1.13.3 | cert-manager install tasks |
| multus_version | v4.2.4-thick | multus daemonset template |
| multus_cni_plugins_version | v1.9.1 | multus DHCP daemon template |
| rancher_version | 2.8.0 | rancher install task |
| rancher_monitoring_version | 103.0.3 | rancher-monitoring install task |
| synology_csi_version | v1.2.1 | synology-csi templates/tasks |
| synology_csi_snapshotter_version | v8.5.0 | synology snapshotter template/tasks |
| csi_nfs_version | v4.13.2 | synology csi-driver-nfs task |
| smoke_test_image | busybox:1.36.1 | scale-nodes, upgrade-k3s functional checks |

## Role/Playbook Version Consumer List

- ansible/playbooks/upgrade-k3s.yml -> `k3s_version`
- ansible/roles/k3s-server/tasks/install.yml -> `k3s_version`
- ansible/roles/k3s-agent/tasks/install.yml -> `k3s_version`
- ansible/roles/cert-manager/tasks/install.yml -> `cert_manager_version`
- ansible/roles/kube-vip/templates/kube-vip-daemonset.yaml.j2 -> `kube_vip_version`
- ansible/roles/kube-vip/templates/kube-vip-cloud-controller.yaml.j2 -> `kube_vip_cloud_provider_version`
- ansible/roles/multus/templates/multus-daemonset-thick.yml.j2 -> `multus_version`
- ansible/roles/multus/templates/multus-dhcp-daemon.yaml.j2 -> `multus_cni_plugins_version`
- ansible/roles/rancher/tasks/install.yml -> `rancher_version`
- ansible/roles/rancher-monitoring/tasks/install.yml -> `rancher_monitoring_version`
- ansible/roles/synology-csi/tasks/install.yml -> `synology_csi_snapshotter_version`
- ansible/roles/synology-csi/tasks/csi-driver-nfs.yml -> `csi_nfs_version`

## Removal Safety Criteria Checklist

- Candidate has no active references in core documentation or supported workflows.
- Candidate has no required dependency in lifecycle playbooks.
- Candidate removal is reflected in cleanup decision record.
- Reference integrity scan passes after removal.
- Lifecycle syntax checks pass after removal.

## Final Completion Summary

- Implemented repository cleanup with obsolete artifact removal (`tests/ansible/smoke/dns-provider-switch-test.yml`).
- Centralized version behavior by removing duplicate role default versions and adding explicit enabled-addon version assertions.
- Replaced floating busybox test image tags with pinned values in lifecycle and smoke validation playbooks.
- Updated contributor and operator documentation for canonical version-source policy and cleanup governance.
- Completed lifecycle playbook syntax checks and ansible-lint run; no blocking failures.

## Follow-Ups

- Consider adding a lightweight script to automate internal docs reference validation in CI.
- Consider moving role README version examples to a shared documentation include for long-term consistency.
