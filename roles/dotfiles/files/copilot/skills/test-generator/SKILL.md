---
name: test-generator
description: Takes a target file or directory as input, consumes established testing standards, and automatically generates high-impact, functional test suites. 
inputs:
  - target_path: The specific file or directory path for which the tests should be generated.
argument-hint: "[target_path]"
---
# Skill: Test Generator

## Purpose
Automatically generate test suite for a specified target `{target_path}`.

## Triggers
* Invoked manually with a specific file or directory path as an argument.
* Triggered automatically after a new feature implementation or refactor is completed.

## Orchestration & Execution

### Phase 1: Context & Standards Retrieval
* **Read the Rules:** Retrieve the current testing protocols from `./standards/index.yml`.
* **Analyze the Target:** Deep dive into the `target_path` (file or directory) to understand the business logic, dependencies, and critical execution paths.
* **Identify the "One Thing":** Determine the core functionality of the target that absolutely must not break, and prioritize testing around it.

### Phase 2: Reusable Asset Discovery (Cross-File Analysis)
* **Scan for Test Infrastructure:** Before generating code, analyze adjacent directories, `conftest.py`, `factories/`, and `utils/` to locate existing reusable values.
* **Identify Shared Assets:** Extract available setup configurations, mock objects, shared constants, and existing `pytest` fixtures (especially those managing complex `yield` and object cleanup logic).
* **Map Dependencies:** Ensure the generated tests will import and utilize these existing assets rather than creating redundant, isolated setup code.

### Phase 3: Pragmatic Generation
* Generate tests that adhere strictly to the established standards and integrate the discovered reusable assets.
* Implement functional engineering principles: rely on global fixtures for state management and keep individual test functions lean. 
* Structure the tests to fail loudly and clearly when business logic is violated. Keep your receipts—ensure test output will be immediately actionable.

### Phase 4: Validation and Persistence
* **Dry Run:** Execute a static check or dry-run of the generated tests to verify syntax, standard compliance, and correct importing of reusable values.
* **Delegate Saving:** Pass the finalized test code payload to a standard file-writing agent to persist the files in the corresponding `tests/` directory structure.

## Constraints & Rules
* **Never Duplicate:** If a fixture, mock, or constant exists elsewhere in the test suite that serves the requirement, you MUST reuse it. Do not bloat the system.
* **No Vanity Metrics:** Do not write tests just to increase code coverage. Every test must prove a functional requirement or protect against a known failure mode.
* **Write for the Next Developer:** The testing framework is a means to an end. Keep the test code simple, readable, highly focused on actual behavior, and free of unnecessary custom setups.

