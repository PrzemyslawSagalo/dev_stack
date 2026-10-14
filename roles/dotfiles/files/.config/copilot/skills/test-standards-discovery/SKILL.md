---
name: test-standards-extractor
description: Scans the `tests` directory to abstract existing testing patterns, mocking strategies, and assertion styles into hard rules. 
             Delegates the documentation and persistence of these standards entirely to the `artifact-generator`.
---

# Skill: Test Standards Extractor

## Purpose
To execute a deep scan of the existing test suites, identify the functional engineering patterns that are actively used, and synthesize them into definitive testing standards.

## Triggers
* When initializing testing standards for a new or inherited project.
* Before executing a major refactor or adding a large batch of new test suites.
* On manual invocation to align agent behavior with the current state of the codebase.

## Orchestration & Execution

### Phase 1: Deep Test Discovery
* Execute a recursive scan of the `tests` directory.
* Identify core patterns: fixture usage, object cleanup logic, mocking boundaries, and assertion conventions.
* Filter out the noise and isolate the high-value, functional patterns that form the backbone of the test suite. 

### Phase 2: Pattern Abstraction
* Synthesize the discovered patterns into pragmatic, unambiguous rules.
* Group the abstractions into logical domains (e.g., Unit, Integration, System).
* Define strict "anti-patterns" based on any brittle or poorly constructed tests found during the scan.

### Phase 3: Handoff to Docs-Manager
* Package the abstracted rules into a structured payload.
* Invoke the `artifact-generator` skill to format, validate, and write the rules into `./standards/testing-standards.md`.
* **Crucial:** Guard your boundaries. Do not perform any direct file system writes. Pass the payload and let the `artifact-generator` do its job.

### Phase 4: General rules of testing 
* Whenerver it is only possible compare raw data not only parameters like dimension, shape, type, etc. but also the actual values of the data.

## Constraints & Rules
* **Truth Over Theory:** Abstract only the patterns that actually exist in the codebase. Do not invent aspirational rules. Deliver the bitter truth about the current state of the tests.
* **Binary Directives:** Extracted rules must be concise, specific, and actionable for the next developer or agent. 
* **Stay in Your Lane:** The sole responsibility of this skill is analysis and abstraction. Persistence is strictly owned by the `artifact-generator`.

