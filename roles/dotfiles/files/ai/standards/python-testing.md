# Python Testing Standards

## Scope

- Applies when writing, auditing, or updating Python test suites.

## Rules

### Framework & Assertions

- **Runner & Assertions:** Exclusively use `pytest` as the test runner and `assertpy` (`assert_that(...)`) for assertions.
- **Layout & Idioms:** Place tests in `tests/test_<filename>.py`, use `pytest.raises` for exception paths, and use `@pytest.mark.parametrize` for input variants and edge cases.

### Logic Focus (Exclude Non-Logic)

- **Target Control Flow:** Focus tests on conditional branches (`if/elif/else`, `match/case`), loops, exception handlers (`try/except/finally`), and `async`/`await` paths.
- **Exclude Non-Logic:** Exclude non-logic lines—such as logging (`logger.*`, `logging.*`, `print()`), docstrings, comments, `pass`, `...`, and trivial stub returns—from coverage targets.

### Data Verification

- **Deep Comparison:** Compare structured outputs (e.g., `pandas.DataFrame`, dictionary payloads, model outputs) against full populated expected data or use `snapshot.check()`.
- **No Shallow Checks:** Do not rely solely on shallow checks such as asserting only shapes, lengths, or column counts.

### Strict Test Isolation

- **Per-Method Isolation:** Never share or reuse data generated inside one test method with any other test method.
- **Order Independence:** Keep each test method self-contained and deterministic so execution order never affects outcomes.
