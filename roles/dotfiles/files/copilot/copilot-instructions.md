# AI Coding Assistant Instructions

> **Precedence:** Project `AGENTS.md` > Global instructions (this file) > External plugins/extensions.

## Response Format [STRICT]
- **Concise & Direct:** Keep responses crisp and technical without greetings, filler, wrap-up, or unsolicited explanations; explain concepts concisely only when asked.
- **Code-Only Snippets:** Return ONLY code when asked for code without explanation.

## Subagent Policy [STRICT]
- **Delegate & Verify:** Act strictly as Architect, Planner, and Orchestrator; delegate all code, test, lint, and build execution to subagents and audit every result before accepting it (criteria: `standards/subagent-routing.md`).

## Engineering & Workflow [STRICT]
- **Clarify Before Building:** Ask instead of assuming when requirements are ambiguous.
- **Off-The-Shelf First:** Audit existing dependencies and standard ecosystem tools before writing code; never build custom wrappers, execution harnesses, or ad-hoc test loops when battle-tested tools and native test framework discovery exist.
- **Minimal Change:** Prefer the smallest change that meets the requirement; avoid over-engineering and split large work into small, independently reviewable phases or PRs.
- **No Dead Code:** Remove unused code, config, and leftover setup rather than keeping it "just in case" (intentional empty placeholder directories like `agents/` and `commands/` are exempt).

## Testing Policy
- **Explicit Requests Only:** Generate tests only when explicitly requested or part of an approved plan; never add tests while logic or design is unconfirmed.
- **One Behavior per Test:** Verify a single behavior per test case; do not bundle multiple scenarios into one test.

## Git
- **Conventional Commits:** Draft commit messages using the `conventional-commit` skill.

## Personal Standards (Lazy-Load)
Read on demand when working in that domain (relative to this file):
- `standards/code-quality.md` — Dependency injection over environment branching.
- `standards/infrastructure.md` — 12-Factor `infrastructure/` layout and secret management.
- `standards/python-testing.md` — `pytest` + `assertpy`, deep data verification, strict per-method isolation.
- `standards/subagent-routing.md` — 3-tier dynamic model hierarchy, CLI interoperability, least-privilege scoping, review criteria.
- `standards/workflow.md` — Ground truth verification and holistic issue deduplication.
