import os
import unittest
import yaml

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WORKFLOW_PATH = os.path.join(REPO_ROOT, ".github", "workflows", "skillspector.yml")


class TestSkillSpectorWorkflow(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.path.isfile(WORKFLOW_PATH), f"Workflow file missing at {WORKFLOW_PATH}")
        with open(WORKFLOW_PATH, "r") as f:
            self.raw_content = f.read()
            self.workflow = yaml.safe_load(self.raw_content)

    def test_01_yaml_schema_and_triggers(self):
        """Test 1: Validate workflow parses as valid YAML and triggers on push and pull_request to main."""
        self.assertIsInstance(self.workflow, dict)
        self.assertIn("name", self.workflow)
        
        # In YAML, 'on' key is often parsed as True/on boolean unless quoted
        triggers = self.workflow.get("on") or self.workflow.get(True)
        self.assertIsNotNone(triggers, "Workflow triggers ('on') must be defined")

        if isinstance(triggers, dict):
            self.assertIn("pull_request", triggers)
            self.assertIn("push", triggers)
            pr_branches = triggers["pull_request"].get("branches", [])
            push_branches = triggers["push"].get("branches", [])
            self.assertIn("main", pr_branches)
            self.assertIn("main", push_branches)
        elif isinstance(triggers, list):
            self.assertIn("pull_request", triggers)
            self.assertIn("push", triggers)

    def test_02_least_privilege_permissions(self):
        """Test 2: Verify workflow declares least-privilege permissions (contents: read, security-events: write, actions: read)."""
        # Can be top-level or job-level
        perms = self.workflow.get("permissions", {})
        jobs = self.workflow.get("jobs", {})
        job = next(iter(jobs.values())) if jobs else {}
        job_perms = job.get("permissions", {})

        effective_perms = {**perms, **job_perms}
        self.assertEqual(effective_perms.get("contents"), "read")
        self.assertEqual(effective_perms.get("security-events"), "write")
        self.assertEqual(effective_perms.get("actions"), "read")

    def test_03_pinned_actions_and_python_setup(self):
        """Test 3: Verify pinned GitHub Actions (checkout@v7, setup-python@v7 3.13 without cache, upload-sarif@v4, upload-artifact@v4)."""
        jobs = self.workflow.get("jobs", {})
        self.assertTrue(len(jobs) >= 1)
        job = next(iter(jobs.values()))
        steps = job.get("steps", [])

        action_uses = [s.get("uses", "") for s in steps if "uses" in s]
        self.assertTrue(any("actions/checkout@v7" in u for u in action_uses), "Missing actions/checkout@v7")
        self.assertTrue(any("actions/setup-python@v7" in u for u in action_uses), "Missing actions/setup-python@v7")
        self.assertTrue(any("github/codeql-action/upload-sarif@v4" in u for u in action_uses), "Missing upload-sarif@v4")
        self.assertTrue(any("actions/upload-artifact@v4" in u for u in action_uses), "Missing upload-artifact@v4")

        setup_python_step = next(s for s in steps if "actions/setup-python@v7" in s.get("uses", ""))
        step_with = setup_python_step.get("with", {})
        self.assertEqual(str(step_with.get("python-version")), "3.13")
        self.assertNotIn("cache", step_with, "cache: 'pip' should be omitted to avoid missing manifest failures")

    def test_04_pinned_skillspector_installation(self):
        """Test 4: Verify SkillSpector Git installation is pinned to @v2.12.0."""
        jobs = self.workflow.get("jobs", {})
        job = next(iter(jobs.values()))
        steps = job.get("steps", [])

        run_scripts = [s.get("run", "") for s in steps if "run" in s]
        expected_pin = "pip install git+https://github.com/NVIDIA/SkillSpector.git@v2.12.0"
        self.assertTrue(
            any(expected_pin in script for script in run_scripts),
            f"Expected pinned install command: {expected_pin}",
        )

    def test_05_dual_pass_scan_parameters(self):
        """Test 5: Verify dual-pass scan invocations configure --fail-on-findings, --no-llm, and target roles/dotfiles/files/.config/copilot/skills without --recursive."""
        jobs = self.workflow.get("jobs", {})
        job = next(iter(jobs.values()))
        steps = job.get("steps", [])

        run_scripts = "\n".join(s.get("run", "") for s in steps if "run" in s)
        self.assertIn("skillspector scan roles/dotfiles/files/.config/copilot/skills", run_scripts)
        self.assertNotIn("--recursive", run_scripts)
        self.assertIn("--baseline .skillspector-baseline.yaml", run_scripts)
        self.assertIn("--no-llm", run_scripts)
        self.assertIn("--fail-on-findings", run_scripts)
        self.assertIn("--format sarif", run_scripts)
        self.assertIn("--output report.sarif", run_scripts)
        self.assertIn("--format markdown", run_scripts)
        self.assertIn("--output report.md", run_scripts)

    def test_06_fault_tolerant_reporting_error_handling(self):
        """Test 6: Verify fault-tolerant step execution: if: always() on SARIF upload (with continue-on-error: true and category: skillspector), if: always() on step summary, and if: always() on artifact upload."""
        jobs = self.workflow.get("jobs", {})
        job = next(iter(jobs.values()))
        steps = job.get("steps", [])

        sarif_step = next(s for s in steps if "upload-sarif" in s.get("uses", ""))
        self.assertEqual(sarif_step.get("if"), "always()")
        self.assertTrue(sarif_step.get("continue-on-error"), "SARIF upload must set continue-on-error: true for fork resilience")
        self.assertEqual(sarif_step.get("with", {}).get("category"), "skillspector")
        self.assertEqual(sarif_step.get("with", {}).get("sarif_file"), "report.sarif")

        summary_step = next(s for s in steps if "$GITHUB_STEP_SUMMARY" in s.get("run", ""))
        self.assertEqual(summary_step.get("if"), "always()")

        artifact_step = next(s for s in steps if "upload-artifact" in s.get("uses", ""))
        self.assertEqual(artifact_step.get("if"), "always()")


if __name__ == "__main__":
    unittest.main()
