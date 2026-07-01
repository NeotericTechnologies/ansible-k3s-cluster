# Quickstart: Repository Cleanup and Documentation Alignment Validation

This quickstart validates the planned cleanup feature outcomes without introducing implementation details.

## 1. Prerequisites

- Repository checkout on branch `002-before-specify`
- Ansible tooling available for syntax/lint checks
- Grep (`grep`) available for reference tracing

## 2. Baseline Reference Audit

Run a repository-wide search for candidate obsolete artifacts and known stale references.

- Example:
  - `grep -RIn "dns-provider-switch-test\|deprecated\|TODO\|hard-coded" ansible docs tests`

Expected outcome:
- Candidate items are identified with path and context for cleanup decisioning.

## 3. Workflow Dependency Validation

Verify that candidate removals do not break primary lifecycle entrypoints.

- Validate syntax of core playbooks:
  - `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-core.yml --syntax-check`
  - `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/cluster-addons.yml --syntax-check`
  - `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/scale-nodes.yml --syntax-check`
  - `ansible-playbook -i ansible/inventories/test-cluster/hosts.ini ansible/playbooks/upgrade-k3s.yml --syntax-check`

Expected outcome:
- No syntax-level regressions in documented lifecycle entrypoints.

## 4. Version Source Validation

Inspect maintained operational artifacts for embedded version literals and verify centralized sources.

- Example searches:
  - `grep -RIn "version:\|_version\|image:" ansible/group_vars ansible/roles ansible/playbooks`
  - `grep -RIn "latest\|:3$\|:latest" ansible docs tests`

Expected outcome:
- Version control points are explicit and reviewable; undocumented hard-coded literals are identified for correction.

## 5. Documentation Consistency Validation

Validate that docs references align with current files.

- Reference integrity scan:
  - `grep -RIn "ansible/playbooks\|ansible/roles\|tests/ansible/smoke\|specs/" README.md docs CONTRIBUTING.md ansible/roles`

Expected outcome:
- Referenced files exist and reflect current workflows.
- Deprecated/removed references are corrected.

## 6. Evidence and Change Record

Prepare the final cleanup mapping:
- Artifact path
- Action (`removed`, `updated`, `retained`)
- Rationale
- Validation evidence

Expected outcome:
- A complete and reviewable cleanup decision record exists for all scoped artifacts.
