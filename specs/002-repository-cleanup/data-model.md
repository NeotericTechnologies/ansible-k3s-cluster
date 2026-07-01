# Data Model: Repository Cleanup and Documentation Alignment

## Overview

This model defines the planning entities used to identify, validate, and execute repository cleanup safely while keeping documentation and version governance aligned with active workflows.

## Entities

### 1. RepositoryArtifact

Represents a file or directory in cleanup scope.

- **Fields**:
  - `path`: Repository-relative path.
  - `kind`: Enum (`playbook`, `role`, `inventory`, `test`, `doc`, `template`, `other`).
  - `status`: Enum (`active`, `candidate-obsolete`, `deprecated`, `removed`).
  - `workflow_links`: List of referenced workflows or entrypoints.
  - `reference_count`: Count of active references found during tracing.
  - `cleanup_action`: Enum (`retain`, `update`, `remove`).
  - `rationale`: Human-readable reason for action.

- **Relationships**:
  - Many-to-many with `DocumentationTopic`.
  - Many-to-many with `WorkflowReference`.

### 2. VersionSource

Represents an approved source location for version values.

- **Fields**:
  - `name`: Logical version key name.
  - `source_path`: Configuration file path where the version is defined.
  - `scope`: Enum (`global`, `inventory`, `role-default`).
  - `is_canonical`: Boolean indicating authoritative source.
  - `consumers`: Artifacts/workflows that read this version.

- **Relationships**:
  - One-to-many with `RepositoryArtifact` (a version source can feed many artifacts).

### 3. DocumentationTopic

Represents a user-facing documentation section related to operational workflows.

- **Fields**:
  - `title`: Topic title.
  - `path`: Document path.
  - `audience`: Enum (`maintainer`, `operator`, `contributor`).
  - `workflow_refs`: Referenced playbooks/tests/inventories.
  - `validation_state`: Enum (`unverified`, `verified`, `needs-update`).
  - `last_validated`: Date of verification against repository state.

- **Relationships**:
  - Many-to-many with `RepositoryArtifact`.
  - One-to-many with `WorkflowReference`.

### 4. WorkflowReference

Represents a documented or operational workflow entrypoint.

- **Fields**:
  - `name`: Workflow name.
  - `entrypoint`: Playbook/test/doc command path.
  - `category`: Enum (`provision`, `addons`, `scale`, `upgrade`, `validation`, `docs`).
  - `required_artifacts`: Paths required for successful execution.
  - `validation_method`: Enum (`search`, `syntax-check`, `lint`, `smoke-test`).
  - `validation_result`: Enum (`pass`, `fail`, `not-run`).

- **Relationships**:
  - Many-to-many with `RepositoryArtifact`.
  - Many-to-one with `DocumentationTopic`.

### 5. CleanupDecisionRecord

Represents the audit trail for each cleanup action.

- **Fields**:
  - `artifact_path`: Target artifact path.
  - `decision`: Enum (`removed`, `updated`, `retained`).
  - `reason`: Why the decision was taken.
  - `replacement`: Optional replacement path/workflow if applicable.
  - `evidence`: Validation evidence summary.
  - `recorded_by`: Maintainer identifier.
  - `recorded_at`: Timestamp.

- **Relationships**:
  - Many-to-one with `RepositoryArtifact`.

## State Transitions

### Artifact Lifecycle

- `active` -> `candidate-obsolete` -> `deprecated` -> `removed`
- `active` -> `update-in-place` -> `active`
- `candidate-obsolete` -> `active` (if references or workflow dependency are confirmed)

### Documentation Lifecycle

- `unverified` -> `verified`
- `verified` -> `needs-update` (when linked artifacts/workflows change)
- `needs-update` -> `verified` (after correction and validation)

## Validation Rules

- An artifact cannot transition to `removed` unless `reference_count = 0` across active docs/tests/workflows or an approved replacement is documented.
- Any artifact tied to core lifecycle workflows must show passing validation evidence before removal.
- Each operational version consumer must map to at least one canonical `VersionSource`.
- Documentation topics referencing changed artifacts must reach `verified` before feature completion.
- Every removal or update action must have a corresponding `CleanupDecisionRecord`.
