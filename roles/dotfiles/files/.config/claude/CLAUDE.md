@~/.config/copilot/copilot-instructions.md

# Delegation to Antigravity

Implementation of well-specified, machine-verifiable work is delegated by default
to the Antigravity CLI (`agy`) through `~/.claude/delegate.sh`. Claude Code writes
the spec and reviews the diff; it does not write the implementation itself unless
delegation is ruled out or has failed through the whole escalation ladder.

## When the decision happens

Before writing or editing implementation code — every time, not only when asked —
run the check below and say the verdict out loud. Never skip it silently: a
default that is only read at session start quietly becomes "never delegate", and
the spoken verdict is what keeps it real.

Keeping the work is one line: `Doing this directly: <reason>`.

Handing it over is announced **before `agy` is started**, never after it has run,
and states all four of:

* what is being handed over, in one sentence;
* the files in scope;
* the model and effort it goes to;
* the command that will decide success.

Then say plainly that the diff comes back for review and that nothing is merged.
Deciding to delegate needs no further permission — announce it and proceed — but
the user must never discover after the fact that a delegate wrote the code. When
a larger piece of work has only a delegated part, say up front which part goes to
`agy` and which part stays here.

Autonomous delegation follows exactly the same loop as `/delegate`: spec,
worktree, delegate, verify, show the diff, stop.

## When to delegate

Delegate only if ALL THREE hold:

* The task can be stated in a few sentences without session history — a stranger
  reading the spec alone could do it.
* Success is checked by a test, a build or a diff shape — not by taste.
* The work is worth a round trip. A worktree, a subprocess and a review cycle
  cost more than a single small edit, so do trivial changes directly: roughly one
  file and under ~20 lines that can be written in one pass.

The sweet spot is work that is long but mechanical, spread over several files, or
backed by a test that can be run.

When a task is part mechanical and part judgment, split it: delegate the
mechanical half with its own verification command and do the rest directly. If it
will not split cleanly, do the whole thing directly.

## Never delegate

* Architecture decisions.
* Code review.
* Anything touching production, secrets or data migrations.
* Multi-layer refactors.

## Escalation ladder — hard cap

1. `gemini-3.8-flash` at medium effort — at most 2 attempts.
2. `gemini-3.1-pro` at high effort — at most 1 attempt.
   (`gemini-3.1-pro` offers only `low` and `high`; there is no medium.)
3. Only then implement the task in Claude Code directly.

Never exceed 3 delegated attempts for one task. A failing attempt is retried with
a sharper spec, not with the same prompt.

## Isolation

* Delegated work runs in a separate git worktree, never in the user's working tree.
* Claude Code reads the diff and the verification command's output. It never reads
  the delegate's full context or reasoning.
* Claude Code does not merge delegated work; it presents the diff for review.
