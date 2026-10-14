#!/bin/bash
#
# delegate.sh - run a coding task on the Antigravity CLI (agy) headlessly.
#
# Claude Code calls this through its symlinked path ~/.claude/delegate.sh to hand
# a well-specified, machine-verifiable task to a cheaper model. The JSON result
# goes to stdout; everything else goes to stderr.

set -euo pipefail

readonly DEFAULT_MODEL="gemini-3.8-flash"
readonly DEFAULT_EFFORT="medium"
readonly DEFAULT_TIMEOUT="10m"
readonly DEFAULT_SANDBOX="1"

usage() {
    cat >&2 <<'USAGE'
Usage: delegate.sh [-C dir] [-m model] [-e effort] [-t timeout] "prompt"

  -C dir      Run the delegate with this directory as its working directory
              (typically a git worktree created for the task).
  -m model    Antigravity model id. See 'agy models'.
              Default: $DELEGATE_MODEL, else gemini-3.8-flash.
              A bare family (gemini-3.8-flash) takes -e; an already
              effort-suffixed id (gemini-3.8-flash-low) ignores it, because
              agy rejects the two together.
  -e effort   Reasoning effort: low | medium | high.
              Default: $DELEGATE_EFFORT, else medium.
  -t timeout  Print-mode timeout, e.g. 90s, 10m. Default: 10m.

Headless print mode cannot prompt for approval and soft-denies every tool
confirmation, so the delegate is run with --dangerously-skip-permissions. That
is scoped to this script: interactive agy keeps its own permission settings.
The blast radius is the worktree the caller passes with -C, and --sandbox adds
terminal restrictions on top. Set DELEGATE_SANDBOX=0 to drop --sandbox if it
gets in the way of the verification command.

The agy JSON response is written to stdout. Diagnostics go to stderr. The exit
status is non-zero when agy fails, and 3 when headless mode auto-denied a tool
so the delegate changed nothing.
USAGE
}

die() {
    echo "delegate.sh: $*" >&2
    exit 1
}

main() {
    local workdir=""
    local model="${DELEGATE_MODEL:-$DEFAULT_MODEL}"
    local effort="${DELEGATE_EFFORT:-$DEFAULT_EFFORT}"
    local timeout="$DEFAULT_TIMEOUT"
    local opt

    while getopts ":C:m:e:t:h" opt; do
        case "$opt" in
            C) workdir="$OPTARG" ;;
            m) model="$OPTARG" ;;
            e) effort="$OPTARG" ;;
            t) timeout="$OPTARG" ;;
            h) usage; exit 0 ;;
            :) usage; die "option -$OPTARG requires an argument" ;;
            *) usage; die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    [ "$#" -eq 1 ] || { usage; die "expected exactly one prompt argument, got $#"; }
    local prompt="$1"
    [ -n "$prompt" ] || die "the prompt must not be empty"

    case "$effort" in
        low|medium|high) ;;
        *) die "invalid effort '$effort' (expected low, medium or high)" ;;
    esac

    command -v agy > /dev/null 2>&1 \
        || die "'agy' (Antigravity CLI) is not on PATH; delegation is unavailable"

    if [ -n "$workdir" ]; then
        [ -d "$workdir" ] || die "working directory '$workdir' does not exist"
        cd "$workdir"
    fi

    echo "delegate.sh: model=$model effort=$effort timeout=$timeout cwd=$PWD" >&2

    # agy rejects --effort when the model id already carries an effort suffix.
    local effort_args=(--effort "$effort")
    case "$model" in
        *-low|*-medium|*-high)
            echo "delegate.sh: model '$model' already sets effort; ignoring -e $effort" >&2
            effort_args=()
            ;;
    esac

    # Print mode soft-denies every tool confirmation, so the delegate cannot edit
    # a file without this. It is deliberately scoped to delegated runs: the
    # user's interactive agy keeps prompting as before.
    local sandbox_args=(--sandbox)
    if [ "${DELEGATE_SANDBOX:-$DEFAULT_SANDBOX}" = "0" ]; then
        echo "delegate.sh: DELEGATE_SANDBOX=0, running without --sandbox" >&2
        sandbox_args=()
    fi

    local status=0 output=""
    output="$(agy --print "$prompt" \
        --output-format json \
        --model "$model" \
        "${effort_args[@]}" \
        "${sandbox_args[@]}" \
        --dangerously-skip-permissions \
        --print-timeout "$timeout")" || status=$?

    # The JSON result goes to stdout whether or not the run was useful.
    [ -n "$output" ] && printf '%s\n' "$output"

    if [ "$status" -ne 0 ]; then
        echo "delegate.sh: agy exited with status $status (model=$model, cwd=$PWD)" >&2
        exit "$status"
    fi

    # agy still exits 0 when headless mode auto-denies a tool it cannot prompt
    # for: the delegate then changes nothing and reports SUCCESS. Catch that,
    # otherwise the caller mistakes a no-op for a finished task.
    local denied=""
    if command -v jq > /dev/null 2>&1; then
        denied="$(printf '%s' "$output" \
            | jq -r '(.denied_actions // []) | map(.display_name // .action) | join(", ")' 2>/dev/null || true)"
    else
        case "$output" in
            *'"denied_actions":[{'*) denied="unknown (install jq for details)" ;;
        esac
    fi

    if [ -n "$denied" ]; then
        echo "delegate.sh: agy auto-denied tools in headless mode: $denied" >&2
        echo "delegate.sh: the delegate changed nothing; add matching entries under" >&2
        echo "             permissions.allow in ~/.gemini/antigravity-cli/settings.json" >&2
        exit 3
    fi
}

main "$@"
