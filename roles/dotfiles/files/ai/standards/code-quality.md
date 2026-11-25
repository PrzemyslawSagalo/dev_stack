# Code Quality Standards

## Scope

- Applies when designing, implementing, or refactoring application, service, or client code across any language.

## Rules

### Pre-Implementation Off-The-Shelf Gate

- **Verify Problem Existence First:** Never polish or replace a legacy workaround with another workaround without first verifying that the underlying issue exists in the target runtime; delete unreachable fallbacks and redundant guards outright.
- **Dependency & Standard Library Audit:** Before writing any helper function, assertion wrapper, temp-directory/cleanup boilerplate, parser, or retry loop, audit installed dependencies and ecosystem standard libraries first.
- **No Custom Glue Over Ecosystem Libraries:** Always adopt an established off-the-shelf library or framework built-in rather than writing custom wrappers. Custom helpers are strictly a last resort and require explicit justification naming the rejected ecosystem alternatives.
- **Single Primitive Over Multi-Step Fallbacks:** When resolving references, paths, or states, use one uniform native primitive across candidates rather than chaining distinct commands and nested fallback branches.

| Ecosystem | Mandatory Off-The-Shelf Tools & Built-Ins | Forbidden Custom Alternatives |
| :--- | :--- | :--- |
| **Bats** | `bats-support`, `bats-assert` (`assert_success`, `assert_failure`, `assert_output`, `assert_line`), `bats-file` (`assert_file_exists`, `assert_file_not_empty`, `assert_dir_exists`, `assert_dir_not_exists`, `assert_file_permission`, `assert_symlink_to`), `$BATS_TEST_TMPDIR` | Custom `assert_*`/`verify_*`/`check_*` wrappers, `mktemp -d` + `teardown()` cleanup, raw `[ "$status" -eq 0 ]`, `[[ "$output" == ... ]]`, `[ -L ... ]`, `readlink -f`, `stat -c` |
| **Python** | `pytest` built-in fixtures (`tmp_path`, `monkeypatch`, `capsys`), `assertpy`, `unittest.mock`, `pathlib`, `shutil`, `tenacity` | Custom temp-dir fixtures, custom assertion helpers, ad-hoc retry loops |
| **Lua / Neovim** | `luassert` (`assert.matches`, `assert.has_no.match`, `assert.are.same`, `assert.are.equal`), `vim.fs.rm`, `vim.fn.undofile`, `vim.iter`, `vim.wait`, `vim.cmd("silent! only!")` | Custom `remove_if_exists` helpers, manual `vim.fn.glob` undofile loops, manual `for` scan loops over diagnostics/windows |
| **Ansible** | `ansible.builtin.*` / `community.general.*` modules, `retries` / `delay` / `until`, `checksum` | Custom `command`/`shell` wrappers, curl-to-sh pipelines, custom retry scripts |

### Dependency Injection over Environment Branching

- **No Environment Flags:** Never use boolean flags (e.g., `USE_SANDBOX`, `IS_DEV`) to branch application logic for different environments or mock services.
- **Externalized Configuration:** Inject service endpoints, base URLs, and credentials via external configuration or environment variables (e.g., `API_BASE_URL`) so code remains environment-agnostic.

## Examples

**Bad:**

```python
# Hardcoding environment branching inside application code
if settings.use_sandbox:
    base_url = "https://sandbox.api.com"
    headers["x-simulated-trading"] = "1"
else:
    base_url = "https://live.api.com"
```

**Good:**

```python
# Base URL is injected via external configuration
self.client = httpx.AsyncClient(base_url=settings.api_base_url)
```
