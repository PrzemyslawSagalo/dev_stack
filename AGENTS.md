# AGENTS.md — Testing Framework Rules, Architecture & Standards for AI Agents

## 1. Overview & Purpose

This document defines the strict testing architecture, framework standards, and rules of engagement for all AI agents and contributors working in the `dev_stack` repository.

All testing practices must align with professional software engineering principles: repeatability, maintainability, isolation, and leveraging battle-tested off-the-shelf tooling.

---

## 2. Core Philosophy: Off-The-Shelf First

* **Zero Custom Test Harnesses**: Never implement custom test runners, ad-hoc execution wrappers, or handwritten test harnesses in Lua, Python, Bash, or any other language.
* **Zero Ad-Hoc File Loops**: Never write custom loops over test files (`for f in tests/*; do ...`). All test runners must rely on their native directory discovery mechanisms.
* **Zero Reinventing the Wheel**: Always utilize established, industry-standard testing frameworks provided by the ecosystem. Custom solutions are strictly prohibited when mature tools exist.

---

## 3. Test Taxonomy & Framework Matrix

| Directory / Target | Test Tier | Framework | Discovery / Execution Command | Environment & Prerequisites | Mocking Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tests/unit` | **Unit Tests** | **Bats-core** (`bats-core`) | `bats --print-output-on-failure tests/unit` | Fast, hermetic, zero system bootstrap | Mock external dependencies; test pure input/output logic |
| `tests/smoke` | **Smoke Tests** | **Bats-core** (`bats-core`) | `bats --print-output-on-failure tests/smoke` | Post-bootstrap (`./bootstrap.sh` required) | Live environment verification (binaries, packages, symlinks) |
| `tests/e2e/nvim` | **End-to-End Tests** | **Plenary Busted** (`plenary.nvim.busted`) | `nvim --headless -c "PlenaryBustedDirectory tests/e2e/nvim {init = vim.fn.stdpath(\"config\") .. \"/init.lua\", sequential = true}"` | Post-bootstrap live Neovim runtime | **Zero mocks**: Real plugins loaded and executed via live Neovim APIs |
| **Python** *(when required)* | **Unit / Integration** | **pytest** + **assertpy** | `pytest tests/` | Virtual environment with required dependencies | Use `pytest` fixtures; deep data assertions with `assertpy` |

### 3.1. Unit Tests (`tests/unit`)
* **Purpose**: Test individual bash scripts, helper functions, and logic branches in complete isolation.
* **Execution**: Must execute in seconds without running `./bootstrap.sh` or installing full desktop environments.
* **Tooling**: Standard `bats-core` assertions and test structure (`@test "description" { ... }`).

### 3.2. Smoke / Verification Tests (`tests/smoke`)
* **Purpose**: Verify that Ansible playbooks and `bootstrap.sh` successfully installed and configured all required packages, configuration files, and tools.
* **Execution**: Runs after `./bootstrap.sh` completes in clean container environments (Ubuntu, Amazon Linux).
* **Tooling**: `bats-core` evaluating filesystem state, command availability (`command -v ...`), and user permissions.

### 3.3. Neovim End-to-End Tests (`tests/e2e/nvim`)
* **Purpose**: Verify Neovim configurations, plugin setups, keymaps, and runtime behaviors.
* **Framework**: Plenary Busted via native headless Neovim execution.
* **Zero-Mock Policy**: Test against real plugins installed in Neovim runtime (`vim-bbye`, `copilot.vim`, `nvim-dap`, `nvim-dap-ui`, etc.). Verify real keymaps, split windows, and lifecycle hooks rather than mocking internal plugin tables.
* **Direct Function Reference Testing**: When testing keymaps that bind directly to plugin or module functions (e.g., DAP, Telescope, LSP), direct function reference equality checking (`assert.are.equal(target_fn, map_info.callback)`) is the recommended standard. This verifies exact function identity in memory without needing to invoke or mock underlying runtime adapters, child processes, or external servers.
* **Assertions**: Standard Busted assertion syntax: `assert.are.same(expected, actual)`, `assert.are.equal(expected, actual)`, `assert.is_true(...)`, `assert.is_not_nil(...)`.

### 3.4. Python Protocol
* Triggered only when Python tests are explicitly required.
* Exclusively use `pytest` as runner and `assertpy` for fluent assertions.
* Deeply verify populated data against real data or snapshots; avoid shallow checks (e.g., merely checking dataframe shapes).
* Ensure strict test isolation: data generated within one test method must never leak to or be reused in other test methods.

---

## 4. Rules of Engagement for AI Agents

1. **Native Directory Discovery**:
   * Always invoke frameworks against test directories:
     * Bats: `bats tests/unit` and `bats tests/smoke`
     * Plenary: `PlenaryBustedDirectory tests/e2e/nvim ...`
     * Pytest: `pytest tests/...`
   * Never introduce intermediate shell scripts or custom file iterators.

2. **Strict Separation of Concerns**:
   * Unit tests belong exclusively in `tests/unit/`. They must never depend on bootstrap state.
   * Smoke tests belong exclusively in `tests/smoke/`.
   * Neovim behavioral and plugin tests belong in `tests/e2e/nvim/`.
   * Never mix unit tests into E2E suites or E2E tests into unit suites.

3. **Pre-Commit Quality Gate**:
   * All code must pass the repository's pre-commit suite with zero warnings and zero errors prior to pushing:
     * `ansible-lint`: Ansible playbooks, roles, tasks, and syntax.
     * `StyLua`: Lua formatting across Neovim configs and E2E test specs.
     * `Luacheck`: Static Lua analysis (`std +busted` for Busted test files).
     * `shellcheck`: Shell script linting and safety checks.
     * `shfmt`: Shell script formatting (`-i 4 -ci`).
   * Run manually with: `pre-commit run --all-files`.

4. **Git & Pull Request Standards**:
   * **Conventional Commits**: Commit messages must follow the Conventional Commits specification (e.g., `fix: ...`, `feat: ...`, `test: ...`).
   * **Atomic PRs**: Exactly 1 atomic commit per pull request. Use `git commit --amend` to update ongoing PR branches.
   * **Push Policy**: Use `git push --force-with-lease` when updating feature branches.
   * **Zero Autonomous Merging**: Never merge pull requests autonomously. Always require explicit human authorization to merge.
