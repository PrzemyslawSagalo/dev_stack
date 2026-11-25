---
name: test-generator
description: Generates functional test suites for a specified target file or directory when explicitly requested by the user, following project AGENTS.md and global testing standards.
argument-hint: "<target-path>"
---

# Test Generator

## Trigger

- Runs **ONLY** on explicit user request to generate tests for `<target-path>`.

## Inputs

- `<target-path>`: Specific file or directory path for which tests should be generated (stop and ask the user if missing).

## Workflow

### Phase 1: Context & Asset Discovery

- **Read Standards:** Read `../../standards/code-quality.md`, project `AGENTS.md` (if present) for repo-specific frameworks and conventions, and (for Python targets) `../../standards/python-testing.md`.
- **Ecosystem Assertion Library Scan:** Check installed test libraries and framework built-ins (e.g., `bats-support`/`bats-assert`/`bats-file`/`$BATS_TEST_TMPDIR` for Bats, `assertpy`/`pytest` built-in fixtures for Python, `luassert`/Neovim APIs for Busted) before designing tests.
- **Analyze Target:** Inspect `<target-path>` to identify core business logic, dependencies, edge cases, and failure modes.
- **Inspect Existing Tests:** Check adjacent test directories (`tests/`, `conftest.py`, helpers) to reuse established setup patterns and conventions.

### Phase 2: Delegated Implementation & Verification

- **Delegate Test Creation & Execution:** Delegate creating or updating test files in the appropriate `tests/` directory and running the relevant test suite (e.g., `pytest`, `bats`) to an implementation subagent instructed to follow `../../standards/code-quality.md`, project `AGENTS.md`, the identified assertion libraries, and (for Python) `../../standards/python-testing.md`.
- **Audit Results:** Review the subagent's test diff and execution output per `../../standards/subagent-routing.md` before accepting.

## Constraints

- **No Vanity Metrics:** Every test must validate real behavior or protect against a concrete failure mode rather than inflating coverage numbers.
- **No Custom Assertion or Temp Helpers:** Exclusively use native framework assertion libraries and built-in isolation (`$BATS_TEST_TMPDIR`, `tmp_path`, `vim.fs.rm`); never define custom `assert_*`/`verify_*`/`check_*` or temp-dir cleanup helpers.
