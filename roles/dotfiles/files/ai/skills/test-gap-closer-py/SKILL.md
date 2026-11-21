---
name: test-gap-closer-py
description: Closes Python test coverage gaps for specific methods or functions when explicitly invoked, using pre-generated HTML coverage reports.
argument-hint: "<source-file> <target-symbols> [<html-coverage-dir>]"
---

# Python Test Gap Closer

## Trigger

- Runs **ONLY** on explicit user request to close uncovered logic gaps in `<target-symbols>` of `<source-file>` using a pre-generated HTML coverage report.

## Inputs

- `<source-file>`: Path to the Python file requiring coverage.
- `<target-symbols>`: Comma-separated list of methods or functions to audit.
- `<html-coverage-dir>` (optional, default `htmlcov/`): Directory containing pre-generated HTML coverage reports.
- Stop and ask the user if `<source-file>`, `<target-symbols>`, or the HTML coverage directory is missing.

## Workflow

### Phase 1: Deep Coverage Audit & Strategy

- **Read Standards:** Read `../../standards/code-quality.md`, `../../standards/python-testing.md`, and project `AGENTS.md` (if present).
- **Locate & Parse Report:** Find the HTML report for `<source-file>` under `<html-coverage-dir>` and extract lines marked `mis` (missing) or `par` (partial) within `<target-symbols>`.
- **Filter & Plan:** Read `<source-file>`, exclude non-logic lines per `../../standards/python-testing.md`, and plan targeted test cases for the remaining uncovered branches using built-in `pytest` fixtures (`tmp_path`, `monkeypatch`, `capsys`).

### Phase 2: Confirmation Hold

- **Present Strategy:** Summarize the uncovered logic branches and planned test cases, without modifying test files.
- **Pause for Approval:** Prompt: `Phase 1 Complete. Coverage gaps identified for <target-symbols>. Type PROCEED to implement the tests.`

### Phase 3: Implementation & Verification Loop

Only after the user replies `PROCEED`:

- **Track Progress:** Track progress across target gaps (e.g., `Gap Coverage Progress: 2/5 gaps`).
- **Delegate Test Implementation:** Delegate writing tests to an implementation subagent instructed to follow `../../standards/code-quality.md`, `../../standards/python-testing.md` (with built-in `pytest` fixtures `tmp_path`, `monkeypatch`, `capsys`), and project `AGENTS.md` overrides.
- **Request Run Command:** Ask the user for the exact command to run tests and regenerate the HTML coverage report before executing.
- **Delegate Execution & Re-Verify:** Delegate running the user-provided command to a subagent, audit the diff and test output per `../../standards/subagent-routing.md`, and inspect the updated HTML coverage report for `<source-file>`.
- **Iterate Until Complete:** Repeat until `<target-symbols>` reach 100% logic coverage, then report the covered symbols (excluding non-logic lines) and added test cases.

## Constraints

- **Scope Isolation:** Modify or add tests only for the specified `<target-symbols>` in `<source-file>`; do not touch unrelated tests or production source code.
- **No Custom Helpers:** Use `assertpy` and built-in `pytest` fixtures (`tmp_path`, `monkeypatch`, `capsys`) directly; never write custom assertion wrappers or manual temp-dir helpers.
