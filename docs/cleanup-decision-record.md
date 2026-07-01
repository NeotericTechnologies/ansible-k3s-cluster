# Cleanup Decision Record

## Feature

- Feature: Repository Cleanup and Documentation Alignment
- Spec: specs/002-repository-cleanup/spec.md
- Plan: specs/002-repository-cleanup/plan.md
- Tasks: specs/002-repository-cleanup/tasks.md
- Date: 2026-07-01

## Decision Mapping

| Artifact Path | Decision | Rationale | Replacement/Notes | Validation Evidence |
|---|---|---|---|---|
| tests/ansible/smoke/dns-provider-switch-test.yml | removed | Candidate obsolete smoke test not part of primary validated smoke suite | Covered by cert-manager role validation and baseline smoke workflow | Reference scan and syntax checks recorded below |
| tests/ansible/smoke/smoke.yml | retained | Baseline smoke entrypoint for cluster health remains required | No reference to removed artifact; kept as-is | Reference scan confirms no stale link |
| ansible/roles/cert-manager/defaults/main.yml | updated | Remove duplicate hard-coded version defaults | Canonical version source remains ansible/group_vars/all.yml | File diff + version scan |
| ansible/roles/kube-vip/defaults/main.yml | updated | Remove duplicate hard-coded version defaults | Canonical version source remains ansible/group_vars/all.yml | File diff + version scan |
| ansible/roles/rancher/defaults/main.yml | updated | Remove duplicate hard-coded version defaults | Canonical version source remains ansible/group_vars/all.yml | File diff + version scan |
| ansible/playbooks/cluster-addons.yml | updated | Add explicit version variable assertions for enabled add-ons | Reinforces centralized version-source policy | Syntax check + file diff |
| ansible/playbooks/scale-nodes.yml | updated | Remove floating busybox image usage | Uses centralized `smoke_test_image` variable | Syntax check + image-tag scan |
| ansible/playbooks/upgrade-k3s.yml | updated | Remove floating busybox image usage | Uses centralized `smoke_test_image` variable | Syntax check + image-tag scan |
| tests/ansible/smoke/scale-test.yml | updated | Remove floating busybox image usage | Pinned to `busybox:1.36.1` for deterministic smoke checks | Image-tag scan |
| tests/ansible/smoke/upgrade-test.yml | updated | Remove floating busybox image usage | Pinned to `busybox:1.36.1` for deterministic smoke checks | Image-tag scan |
| tests/ansible/smoke/synology-pvc-test.yml | updated | Remove floating busybox image usage | Pinned to `busybox:1.36.1` in inline pod manifests | Image-tag scan |
| README.md | updated | Align docs to current workflow and version policy | Added centralized version guidance and cleanup-aware references | Reference scan |
| docs/ansible-k3s-baseline.md | updated | Align baseline docs with current validated workflows | Updated wording and version policy guidance | Reference scan |
| docs/ansible-structure.md | updated | Add canonical version-source policy and corrected spec links | Clarifies version ownership and maintenance rules | Reference scan |
| CONTRIBUTING.md | updated | Add cleanup process and version-centralization contribution rules | Improves contributor consistency | Reference scan |
| ansible/roles/*/README.md (selected) | updated | Fix stale links and remove embedded hard-coded version examples | Align with centralized version policy | Reference scan |

## Validation Evidence

### Reference Integrity

- Command: `grep -RIn "dns-provider-switch-test" README.md docs tests ansible || true`
- Result: no active references remain in runtime code or contributor-facing documentation.

### Lifecycle Syntax Checks

- Command: `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-core.yml --syntax-check`
- Command: `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-addons.yml --syntax-check`
- Command: `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/scale-nodes.yml --syntax-check`
- Command: `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/upgrade-k3s.yml --syntax-check`
- Result: passed for all four lifecycle playbooks.

### Lint

- Command: `ansible-lint ansible/playbooks/cluster-core.yml ansible/playbooks/cluster-addons.yml ansible/playbooks/scale-nodes.yml ansible/playbooks/upgrade-k3s.yml`
- Result: passed with environment-level warnings about unavailable `kubernetes.core` modules during options validation in this dev container.

### Quickstart Validation Commands

- Command set from specs/002-repository-cleanup/quickstart.md section 2-5
- Result: completed via targeted grep scans (artifact references, version literals, documentation links) plus lifecycle syntax/lint validations.
