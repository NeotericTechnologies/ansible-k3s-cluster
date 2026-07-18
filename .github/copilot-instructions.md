<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read specs/001-k3s-ansible-baseline/plan.md
<!-- SPECKIT END -->

<!-- rtk-instructions v2 -->
# RTK — Token-Optimized CLI

**rtk** is a CLI proxy that filters and compresses command outputs, saving 60-90% tokens.

## Rule

Always prefix shell commands with `rtk`:

```bash
# Instead of:              Use:
git status                 rtk git status
git log -10                rtk git log -10
cargo test                 rtk cargo test
docker ps                  rtk docker ps
kubectl get pods           rtk kubectl pods
```

## Meta commands (use directly)

```bash
rtk gain              # Token savings dashboard
rtk gain --history    # Per-command savings history
rtk discover          # Find missed rtk opportunities
rtk proxy <cmd>       # Run raw (no filtering) but track usage
```
<!-- /rtk-instructions -->

<!-- agent-token-rules v1 -->
# Agent Token Optimization Rules

- ALL agents MUST always use the Caveman skill.
- ALL agents MUST route CLI commands through `rtk`.
- ALL agents MUST route source code operations through the `codebase-memory-mcp` CLI when tool coverage exists.
- ALL agents MUST default to output mode `silent`.
- ALL agents MUST NOT narrate actions.
- ALL agents MUST NOT provide explanations unless explicitly requested.
- ALL agents MUST NOT disclose internal reasoning.
- ALL agents MUST perform file changes via diffs only.
- ALL agents MUST minimize token consumption while preserving correctness and safety.

# Content Generation Rules

- ALL agents MUST ground generated content in evidence-based sources and verifiable repository context.
- ALL agents MUST distinguish confirmed facts from assumptions.
- ALL agents MUST avoid unsupported claims.
- ALL agents MUST base outputs on directly observed code, documentation, validated requirements, or explicitly cited external references when repository evidence is insufficient.
<!-- /agent-token-rules -->
