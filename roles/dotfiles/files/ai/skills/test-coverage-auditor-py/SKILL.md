---
name: test-coverage-auditor-py
description: Audits Python test coverage when explicitly invoked by parsing pre-generated coverage reports, inspecting src/, weighing architectural risk, and writing a Sphinx .rst report.
argument-hint: "<coverage-report-path> <codebase-analysis-report>"
---

# Python Test Coverage Auditor

## Trigger

- Runs **ONLY** on explicit user request to audit Python test coverage from a pre-generated coverage report and codebase analysis.

## Inputs

- `<coverage-report-path>`: Path to the pre-generated coverage artifact.
- `<codebase-analysis-report>`: Path to the codebase analysis report.
- Stop and ask the user if either input path is missing.

## Workflow

### Phase 1: Deep Source Audit & Documentation

- **Ingest Global Context:** Read `<codebase-analysis-report>` to understand architecture and critical data flows.
- **Parse Coverage:** Read `<coverage-report-path>`, filter for files under `src/`, and sort alphabetically by file path.
- **Evaluate Semantic Coverage:**
  - **100% Coverage:** Leave audit detail columns blank and mark Lead Decision as `[OK]`.
  - **Under 100% Coverage:** Read the raw `.py` source from `src/`, filter uncovered lines against `../../standards/python-testing.md` (logic vs non-logic), and map remaining missing lines to classes, functions, branches, or `try/except` blocks.
- **Assess Architectural Risk:** Rate critical API boundaries, error handling, or data integrity paths as `High`/`Critical` risk, and internal DTOs or non-critical boilerplate as `Low` risk.
- **Write Audit Report:** Have a delegated subagent write `doc/test_coverage_audit.rst` (using the reStructuredText format below) and add `test_coverage_audit` to a `toctree` in `doc/index.rst` if missing from `doc/`.

### Phase 2: Confirmation Hold

- **Verify Report Output:** Confirm `doc/test_coverage_audit.rst` was written, `< 100%` files under `src/` were analyzed, and `doc/index.rst` was checked.
- **Pause for Triage:** Stop without generating test code or summarizing findings and prompt: `Phase 1 Complete. Coverage report written to doc/test_coverage_audit.rst. Type PROCEED to start the interactive triage review.`

### Phase 3: Interactive Review Protocol

Only after the user replies `PROCEED`:

- **Track Progress:** Display triage progress (e.g., `Review Progress: 4/10 cases`).
- **Present Decision Item:** Show the highest-priority uncovered block with its source snippet and architectural risk.
- **Apply Triage Choice:** Have a delegated subagent update the `.rst` row's Lead Decision to `[BACKLOG]` on `[Backlog]`, or to `[RISK ACCEPTED]` with Risk Level `Low` on `[Accept Risk]`.
- **Iterate:** Continue to the next uncovered module until triage completes.

### Output Format (reStructuredText)

```rst
===================================
Python Coverage Exception Report
===================================

.. list-table::
   :widths: 20 8 8 8 26 10 15
   :header-rows: 1

   * - File
     - Stmts
     - Miss
     - Cov %
     - Exact Uncovered Code & Global "Why"
     - Risk Level
     - Lead Decision
   * - `src/pkg-name/base.py`
     - 223
     - 37
     - 76%
     - **Code:** `except TimeoutError:` block in `fetch()`. **Why:** Core API boundary; unhandled timeouts cascade and crash ingest.
     - Critical
     - `[TODO]`
   * - `src/pkg-name/sub-pkg/__init__.py`
     - 0
     - 0
     - 100%
     -
     -
     - `[OK]`

Detailed Action Plan
====================
*(List remediation steps ONLY for modules marked `[TODO]`; `<test-cases-needed>` must reference standard `pytest` (`tmp_path`, `monkeypatch`, `capsys`) and `assertpy` patterns and must not recommend custom assertion or fixture helpers)*

- **src/pkg-name/file.py**: <test-cases-needed>
```

## Constraints

- **Audit Only:** Never generate test code during coverage auditing or triage unless explicitly requested.
