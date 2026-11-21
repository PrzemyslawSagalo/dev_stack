# Subagent Routing Standards

## Scope

- Applies when delegating tasks to subagents, selecting models across tiers, invoking external CLI agents, or reviewing subagent outputs.

## Rules

### Dynamic Model Routing (Cost vs Time vs Quality)

- **Tier 1 — Architecture, Planning & Orchestration (High / Reasoning Tier):** Claude Opus 5.5 / Sonnet 5.5, Gemini 4 (Neon / Argon / Pro, subagent `pro`), GPT-5.x (e.g. GPT-5.6) / o-series. Exclusively for high-level trade-offs, architecture, reviewing subagents, and user communication — never for routine execution.
- **Tier 2 — Code Implementation, Refactoring & Complex Tests (Fast / Balanced Tier):** Gemini 4 Hydrogen / Gemini 3.8 Flash (subagent `flash`), Claude Haiku / Sonnet (Low), GPT-5-mini, Copilot `--model auto`. Highest cost-to-performance ratio and minimal latency for writing code, test suites, and bug fixes.
- **Tier 3 — Trivial, Formatting, Linters & Scans (Light / Ultra-fast Tier):** Gemini Flash-Lite (subagent `flash_lite`), GPT-OSS / mini / nano models. Running pre-commit, fixing formatting, audits, status gathering, and templated issues.
- **Cost-Optimal Routing:** Never use a high-cost reasoning tier when a fast or light tier achieves equivalent quality in less time at lower cost.

### Subagent & CLI Interoperability

- **Prefer Native Delegation:** Prefer the native subagent/task delegation of the active CLI (`agy`, `copilot`, `opencode`).
- **External Copilot CLI:** When delegating to external GitHub Copilot CLI (`copilot -p "..." -s --no-ask-user` or `copilot --fleet`), include `-s --no-ask-user` so non-interactive runs do not block.
- **Least-Privilege Permissions**: Default to read-only access for reviews and audits, or explicitly scope tool permissions (e.g., `--allow-tool 'write' --deny-tool 'shell(git push)'`) inside trusted workspaces; never pass `--allow-all` without explicit user opt-in.

### Subagent Quality Gate & Rigorous Review

- **Delegation Brief Requirement:** Every subagent delegation brief must specify the required ecosystem libraries/built-ins for the target stack (per `standards/code-quality.md` and project `AGENTS.md`) and explicitly forbid custom assertion, temp-file, or shell wrappers.
- **Pre-Review Function Scan:** Before accepting any diff, scan added `function`/`def`/Lua `local function` definitions and shell conditionals (`[ "$status" ... ]`, `[[ "$output" ... ]]`, `mktemp`, `readlink`, `stat`) to confirm no custom helper reimplements a framework or ecosystem library built-in.
- **Review Criteria:** Audit every subagent diff, test, script, and config against Clean Code, separation of concerns, idempotency, off-the-shelf library usage, and project standards.
- **Rejection Criteria:** Reject and require rework whenever a subagent introduces custom assertion/temp/cleanup helpers, raw shell status/output/symlink checks where `bats-assert`/`bats-file` apply, architectural flaws, test-runner inception (nesting suites inside runners), brittle regexes, duplicate logic, orphaned files, or substandard hacks.
