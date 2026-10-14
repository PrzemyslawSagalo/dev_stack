---
description: Delegate a well-specified, machine-verifiable coding task to the Antigravity CLI in an isolated git worktree, then review the diff.
argument-hint: <task to delegate, e.g. "add a --dry-run flag to init.sh">
allowed-tools: Bash, Read, Edit, Glob, Grep
---

The task to delegate is: $ARGUMENTS

Follow the delegation policy in `~/.claude/CLAUDE.md`. If the task fails either
gate — it cannot be stated without session history, or success cannot be checked
by a test, a build or a diff shape — say so and stop; do not delegate it.

## (a) Write the spec

Produce a short spec, and show it to me before running anything:

* **Files in scope** — the exact paths the delegate may touch.
* **Change required** — what must be true afterwards, in a few sentences, with
  no reference to this conversation.
* **Verification command** — the single command that decides success.

## (b) Create the worktree

```bash
git worktree add ../<repo>-delegate-<slug> -b delegate/<slug>
```

Derive `<slug>` from the task. Never let the delegate work in my working tree.

## (c) Run the delegate

```bash
~/.claude/delegate.sh -C <worktree> "<spec>"
```

Pass the spec as one prompt argument, including the verification command. The
script prints agy's JSON result on stdout and diagnostics on stderr.

## (d) Verify

Run the verification command inside the worktree yourself. Do not take the
delegate's word for it.

## (e) Report and stop

Show me:

* `git -C <worktree> diff` — the full diff.
* The verification command's output.
* One line on whether the diff stays within the files in scope.

Then stop. Do not merge, do not push, do not remove the worktree — I review it.

## On failure

Follow the escalation ladder from `~/.claude/CLAUDE.md`, sharpening the spec on
each retry rather than resending the same prompt:

1. `-m gemini-3.8-flash -e medium` — at most 2 attempts.
2. `-m gemini-3.1-pro -e high` — at most 1 attempt.
3. Cap reached: tell me the ladder is exhausted and implement it directly.

Reset the worktree between attempts (`git -C <worktree> checkout -- .` plus
`git -C <worktree> clean -fd`) so attempts do not stack on each other.
