# Workflow Standards

## Scope

- Applies before planning or implementing changes and when triaging or consolidating issues across a repository.

## Rules

### Pre-Implementation Research

- **Ground Truth Verification:** Cross-reference proposed changes against the current codebase state, recent merged PRs, and active feature branches before planning or implementing; never base decisions on outdated assumptions or obsolete paths.

### Holistic Issue Deduplication

- **Pre-Planning Triage:** Check related issues across the stack before planning.
- **Close Resolved Issues:** Close any issue that is already resolved, referencing the solving PR.
- **Consolidate Overlaps:** Merge overlapping or subset issues into a single canonical issue and close redundant ones to prevent fragmented plans and merge conflicts.
