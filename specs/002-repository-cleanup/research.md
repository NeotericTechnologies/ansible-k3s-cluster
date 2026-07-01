# Phase 0 Research: Repository Cleanup and Documentation Alignment

## R-001: Safe Obsolete Artifact Removal Gate

- **Decision**: Remove an artifact only when three checks pass: no active references in playbooks/roles/docs/tests, no dependency in supported workflows, and no dependency in example or active inventories.
- **Rationale**: This avoids regressions while reducing repository noise and directly satisfies cleanup requirements for correctness over speed.
- **Alternatives Considered**:
  - **Immediate deletion after visual inspection**: Rejected because hidden references in docs/tests are easy to miss.
  - **Never removing deprecated assets**: Rejected because stale artifacts increase maintenance burden and contributor confusion.

## R-002: Staged Deprecation-Then-Removal Pattern

- **Decision**: For uncertain candidates, use a staged path (mark deprecated, document replacement/removal intent, then remove in a follow-up once references are gone).
- **Rationale**: Reduces operational risk and gives maintainers a compatibility window where needed.
- **Alternatives Considered**:
  - **Single-step hard deletion for all candidates**: Rejected due to higher breakage risk for less-visible workflows.
  - **Permanent deprecation without removal**: Rejected because technical debt remains indefinitely.

## R-003: Version Centralization Strategy

- **Decision**: Treat repository-level group variables as the canonical source for maintainable component versions and eliminate undocumented hard-coded versions from operational artifacts.
- **Rationale**: Centralized version values make upgrades auditable, reduce drift between roles/playbooks, and align with constitution requirements for pinned and configurable k3s behavior.
- **Alternatives Considered**:
  - **Keeping versions in mixed locations**: Rejected because updates become error-prone and non-discoverable.
  - **Using floating/latest tags**: Rejected because it undermines reproducibility and controlled upgrades.

## R-004: Image and Manifest Pinning Rule

- **Decision**: Use explicit, reviewable version pins for container images and fetched manifests used by automation; avoid implicit moving targets.
- **Rationale**: Deterministic deployments and safer rollback behavior require stable artifact references.
- **Alternatives Considered**:
  - **Unpinned references for convenience**: Rejected because behavior changes over time without code changes.

## R-005: Documentation Validation Approach

- **Decision**: Validate documentation by checking internal path/reference integrity and by executing documented entrypoint syntax checks for representative workflows.
- **Rationale**: Documentation accuracy is best proven by runnable guidance and resolved references, not prose review alone.
- **Alternatives Considered**:
  - **Manual-only doc review**: Rejected because it does not consistently catch stale paths or command drift.
  - **Heavy full-environment end-to-end validation for every doc change**: Rejected for this phase as too costly; targeted validation gives high value quickly.

## R-006: Required Change Record Format

- **Decision**: Track cleanup outcomes with a concise mapping of artifact -> action (removed/updated/retained) -> rationale -> replacement/location.
- **Rationale**: This supports auditability and meets the requirement for clear rationale on cleanup decisions.
- **Alternatives Considered**:
  - **Only relying on git diff history**: Rejected because rationale is not always explicit in file diffs.

## R-007: Scope Guardrails for This Feature

- **Decision**: Constrain this feature to repository cleanup and documentation alignment; do not expand into architecture redesign or new runtime capabilities.
- **Rationale**: Keeps delivery focused and measurable against existing feature success criteria.
- **Alternatives Considered**:
  - **Bundling broader refactors in the same effort**: Rejected because it obscures cleanup impact and increases delivery risk.
