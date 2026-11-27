# CI/CD & Branch Protection Standards

## Scope

- Applies when creating or modifying GitHub Actions CI workflows or configuring repository branch protection.

## Rules

### Canonical CI Aggregator Gate (ci-gate)

- **Single Stable Context:** Define a final aggregator job with ID and name `ci-gate` (`name: ci-gate`) in `.github/workflows/ci.yml` so GitHub branch protection tracks a single stable check context across job and matrix changes.
- **Complete Dependencies:** List EVERY upstream job in `needs:` (including parent jobs, not only leaf jobs, so failed parent jobs cannot hide behind skipped dependents) and set `if: always()`.
- **Failure Check:** Fail the gate step when any upstream job did not succeed:
  - Unconditional workflows: `contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') || contains(needs.*.result, 'skipped')`.
  - Workflows with intentional path or branch conditions: `contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled')`.
- **Least Privilege:** Default workflow permissions to read-only (`contents: read`) and grant elevated scopes only on individual jobs that require them.

### Branch Protection Policy

- **Default Branch:** Protect `main` with `required_status_checks` (`strict: true`, `contexts: ["ci-gate"]`), `enforce_admins: true`, `allow_force_pushes: false`, and `allow_deletions: false`.

## Examples

```yaml
  ci-gate:
    name: ci-gate
    needs: [lint, test_unit, test_e2e]
    if: always()
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Fail if any upstream job did not succeed
        if: contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') || contains(needs.*.result, 'skipped')
        env:
          UPSTREAM_RESULTS: ${{ toJSON(needs) }}
        run: |
          echo "Upstream CI jobs did not succeed: $UPSTREAM_RESULTS" >&2
          exit 1
```
