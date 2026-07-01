# Contracts: Repository Cleanup and Documentation Alignment

This document defines user-facing and maintainer-facing contracts for cleanup execution and validation in this repository.

## Contract C-001: Obsolete Artifact Evaluation

- **User Action**: "Identify whether an artifact should be removed, updated, or retained."
- **Input**:
  - Candidate artifact path(s)
  - Active workflow map (provision, addons, scale, upgrade, validation)
  - Reference trace output across docs/tests/playbooks/roles
- **Expected Behavior**:
  - Artifact is marked with one action: retain/update/remove.
  - Removal is allowed only when active references are resolved or replaced.
  - Decision includes explicit rationale.
- **Observable Outcome**:
  - Decision record exists for each candidate artifact.

## Contract C-002: Version Source Normalization

- **User Action**: "Remove hard-coded versions from operational artifacts."
- **Input**:
  - Current version literals discovered in repository artifacts
  - Approved version source locations
- **Expected Behavior**:
  - Operational artifacts consume version values from approved source variables.
  - Undocumented embedded version literals are removed from maintained paths.
- **Observable Outcome**:
  - Version updates are possible through designated configuration locations only.

## Contract C-003: Documentation Accuracy Verification

- **User Action**: "Validate that documentation matches current repository behavior."
- **Input**:
  - Updated docs set
  - Current artifact/workflow paths
  - Validation commands for representative workflows
- **Expected Behavior**:
  - Broken/stale references are removed or corrected.
  - Documented commands and paths are verifiable for current structure.
- **Observable Outcome**:
  - Documentation references resolve and validation checks pass for primary workflows.

## Contract C-004: Cleanup Change Record

- **User Action**: "Produce an auditable cleanup summary."
- **Input**:
  - Final set of removed/updated/retained artifacts
  - Validation evidence snapshots
- **Expected Behavior**:
  - Each changed artifact has an explicit rationale and outcome mapping.
  - Replacement path/workflow is noted when removal affects prior references.
- **Observable Outcome**:
  - A single cleanup decision mapping is available for review and future maintenance.
