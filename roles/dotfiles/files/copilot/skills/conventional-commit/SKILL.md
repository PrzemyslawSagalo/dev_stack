---
name: conventional-commit
description: Drafts ready-to-use Conventional Commit messages from staged or unstaged git diffs without staging files or running git commit.
argument-hint: "[<scope-or-issue-ref>]"
---

# Conventional Commit

## Trigger

- Runs when drafting a Conventional Commit message from staged or unstaged repository changes.

## Inputs

- `<scope-or-issue-ref>` (optional): Scope noun or issue reference (e.g., `dotfiles`, `#143`) to incorporate when appropriate.

## Workflow

- **Inspect Diff:** Read staged changes with `git diff --cached`; if nothing is staged, fall back to `git diff`.
- **Draft Message:** Format the message per Conventional Commits v1.0.0:
  ```text
  <type>[optional (<scope>)][optional !]: <description>

  [optional body]

  [optional footer(s)]
  ```

### Allowed Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation-only changes
- `style`: Formatting or whitespace changes with no behavior change
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `build`: Build system or external dependency changes
- `ci`: CI configuration and workflow changes
- `chore`: Routine maintenance tasks
- `revert`: Reverts a previous commit

### Guidelines

- **Scope:** Optional lowercase noun naming the affected module or area (e.g., `parser`, `ui`, `dotfiles`).
- **Description:** Required concise imperative summary in lowercase without a trailing period (e.g., `add array parsing`).
- **Breaking Changes:** Append `!` after type/scope and/or include a `BREAKING CHANGE: <details>` footer.
- **Body & Footers:** Separate subject, body, and footers with a blank line; place breaking changes or issue references (e.g., `Closes #123`) in footers.

### Examples

```text
feat(parser): add ability to parse arrays
```

```text
feat(auth)!: require API token for CLI requests

BREAKING CHANGE: unauthenticated requests are no longer accepted.

Closes #42
```

## Constraints

- **Read-Only Git Inspection:** Never run `git add` or `git commit` (including `--amend`); return the drafted text for the user or caller to apply.
- **Message-Only Reply:** Return only the ready-to-use Conventional Commit message text with no surrounding commentary or shell commands.
