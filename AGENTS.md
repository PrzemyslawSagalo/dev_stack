# AGENTS.md — dev_stack Project Instructions

## Testing Architecture

| Directory / Target | Test Tier | Framework | Discovery / Execution Command | Environment & Prerequisites | Mocking Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tests/unit` | **Unit Tests** | **Bats-core** (`bats-core`) | `bats --print-output-on-failure tests/unit` | Fast, hermetic, zero system bootstrap | Mock external dependencies; test pure input/output logic |
| `tests/smoke` | **Smoke Tests** | **Bats-core** (`bats-core`) | `bats --print-output-on-failure tests/smoke` | Post-bootstrap (`./bootstrap.sh` required) | Live environment verification (binaries, packages, symlinks) |
| `tests/e2e/cli` | **CLI End-to-End Tests** | **Bats-core** (`bats-core`) | `bats --print-output-on-failure tests/e2e/cli` | Post-bootstrap live CLI/shell environment | Behavioral validation of CLI tools and workflows (zero mocks) |
| `tests/e2e/nvim` | **Neovim End-to-End Tests** | **Plenary Busted** (`plenary.nvim.busted`) | `nvim --headless -c "PlenaryBustedDirectory tests/e2e/nvim {init = vim.fn.stdpath(\"config\") .. \"/init.lua\", sequential = true}"` | Post-bootstrap live Neovim runtime | **Zero mocks:** Real plugins loaded and executed via live Neovim APIs |

### Testing Rules

- **Strict Tier Separation:** Never mix unit, smoke, CLI E2E, or Neovim E2E tests across tier directories.
- **Neovim E2E (`tests/e2e/nvim`):** Test against real installed plugins (`vim-bbye`, `copilot.vim`, `nvim-dap`, `nvim-dap-ui`, etc.) using standard Busted assertions (`assert.are.same`, `assert.are.equal`, `assert.is_true`, `assert.is_not_nil`); for keymaps bound directly to plugin or module functions (DAP, Telescope, LSP), assert direct function identity (`assert.are.equal(target_fn, map_info.callback)`).

## Pre-Commit Quality Gate

- **Zero-Warning Gate:** Run `pre-commit run --all-files` and ensure zero errors or warnings before pushing:
  - `ansible-lint`: Ansible playbooks, roles, tasks, and syntax.
  - `StyLua`: Lua formatting across Neovim configs and E2E test specs.
  - `Luacheck`: Static Lua analysis (`std +busted` for Busted test files).
  - `shellcheck`: Shell script linting and safety checks.
  - `shfmt`: Shell script formatting (`-i 4 -ci`).

## Git & Pull Request Policy

- **Atomic PRs:** Maintain exactly 1 atomic commit per pull request; update ongoing PR branches with `git commit --amend`.
- **Push Policy:** Update feature branches using `--force-with-lease` with `git push`.
- **Zero Autonomous Merging:** Never merge pull requests autonomously; always require explicit human authorization.

## Ansible & Cryptographic Integrity

- **Native Modules Over Custom Shells:** Strictly use native Ansible modules (`ansible.builtin.*`, `community.general.*`) and native task attributes (`retries`, `delay`, `until`, `cache_valid_time`, `deb822_repository`, `rpm_key`, `checksum`) instead of ad-hoc `command`, `shell`, or curl-to-sh pipelines.
- **Strict Cryptographic Integrity:** Never bypass GPG signature or cryptographic checksum verification (`disable_gpg_check: true` and `VERIFY_CHECKSUM: "false"` are strictly forbidden); install tools via official GPG-signed package repositories or verified binary releases with pinned cryptographic checksums.
