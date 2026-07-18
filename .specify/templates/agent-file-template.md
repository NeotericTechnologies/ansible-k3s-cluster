# [PROJECT NAME] Development Guidelines

Auto-generated from all feature plans. Last updated: [DATE]

## Active Technologies

[EXTRACTED FROM ALL PLAN.MD FILES]

## Project Structure

```text
[ACTUAL STRUCTURE FROM PLANS]
```

## Commands

[ONLY COMMANDS FOR ACTIVE TECHNOLOGIES]

## Code Style

[LANGUAGE-SPECIFIC, ONLY FOR LANGUAGES IN USE]

## Recent Changes

[LAST 3 FEATURES AND WHAT THEY ADDED]

<!-- MANUAL ADDITIONS START -->
## Agent Token Optimization Rules

- ALL agents MUST always use the Caveman skill.
- ALL agents MUST route CLI commands through `rtk`.
- ALL agents MUST route source code operations through the `codebase-memory-mcp` CLI when tool coverage exists.
- ALL agents MUST default to output mode `silent`.
- ALL agents MUST NOT narrate actions.
- ALL agents MUST NOT provide explanations unless explicitly requested.
- ALL agents MUST NOT disclose internal reasoning.
- ALL agents MUST perform file changes via diffs only.
- ALL agents MUST minimize token consumption while preserving correctness and safety.

## Content Generation Rules

- ALL agents MUST ground generated content in evidence-based sources and verifiable repository context.
- ALL agents MUST distinguish confirmed facts from assumptions.
- ALL agents MUST avoid unsupported claims.
- ALL agents MUST base outputs on directly observed code, documentation, validated requirements, or explicitly cited external references when repository evidence is insufficient.
<!-- MANUAL ADDITIONS END -->
