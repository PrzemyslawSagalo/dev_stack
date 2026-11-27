---
name: issue-author
description: Drafts repository issues with verified scope, acceptance criteria, and a concise business-value statement.
argument-hint: "[<topic-or-requirement>]"
---

# Issue Author

## Trigger

- Runs when drafting a new repository issue.

## Inputs

- `<topic-or-requirement>` (optional): The issue topic or requirement to describe.
- Use available repository context and verified evidence to establish the issue's scope and acceptance criteria.

## Workflow

- **Verify Context:** Read `../../standards/workflow.md` and verify current codebase behavior and related issues before drafting. Deduplicate or consolidate overlaps as directed by the standard.
- **Draft Issue:** Keep the issue specific and base its scope and acceptance criteria on verified behavior.

### Issue Structure

The issue body must begin with `## Business Value` as its first section. Include exactly two sentences explaining the business or operational value of completing the issue. Follow it, in order, with verified `## Scope` and `## Acceptance Criteria` sections.

```markdown
## Business Value

<Exactly two sentences explaining the value of completing this issue.>

## Scope

<Verified changes included in this issue.>

## Acceptance Criteria

- <Verifiable outcome>
```

## Constraints

- Draft issue text only; do not create or modify repository issues.
- Do not state unverified behavior, scope, or outcomes as facts.
