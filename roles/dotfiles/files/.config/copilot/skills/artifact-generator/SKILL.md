---
name: artifact-generator
description: Generates, enforces, and maintains the rules of engagement within `./standards`. 
---
# Skill: Agent Standards Docs Manager

## Purpose
To generate, manage, and enforce standard operating procedures for all AI agents within the `./standards` directory. 
This skill ensures agents operate predictably, follow strict constraints, and generate high-value output without deviation.

## Triggers
* When standardizing a new project or updating agent instructions.
* When a bottleneck or repetitive error is detected in agent workflows.
* When executing a manual standards refresh via command.

## Orchestration & Execution

### Phase 1: Context Discovery
* Scan the `./standards` directory to index existing `.md` or `.yml` files.
* Identify missing protocols (e.g., execution constraints, code review pragmatism, formatting rules).

### Phase 2: Standards Generation
Draft concise, actionable rules designed for machine consumption. Ensure the generated standards include:
*   **`~/.config/copilot/standards/`**: Global project standards covering baseline rules (e.g., infrastructure isolation, secret management).
*   **`./standards/`**: Local project standards. When generating or enforcing rules, ensure local project standards override global ones.
*   **`execution-protocols.md`**: Hard limits on autonomous actions, enforcing focus on high-impact tasks over empty motion.
*   **`communication-style.md`**: Strict formatting rules (no fluff, direct answers, clear hierarchies).
*   **`code-quality.md`**: Directives for writing scalable architecture and clean code for the next developer.

### Phase 3: Validation & Saving
* Cross-reference newly generated standards with existing files to prevent rule conflicts.
* **Delegation & Initialization:** ALL file write operations MUST be executed by the `artifact-generator` skill itself. If the `./standards/` or `~/.config/copilot/standards/` directories do not exist, the `artifact-generator` MUST create them before saving any files. Generate and save the documentation files directly.
* Generate `./standards/index.yml` (local) or `~/.config/copilot/standards/index.yml` (global) to provide a structured overview of all standards and their relationships.

## Constraints & Rules
* **No Fluff:** Standards must be brief, binary, and impossible for an agent to misinterpret.
* **Immutable Core:** Never overwrite existing standards without explicit validation of the structural change.
* **No Delegation Needed:** The artifact-generator is responsible for directly generating and saving to `./standards/`.

