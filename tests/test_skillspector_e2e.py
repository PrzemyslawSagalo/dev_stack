import os
import shutil
import subprocess
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
VENV_BIN = os.path.join(REPO_ROOT, ".venv", "bin")
BASELINE_PATH = os.path.join(REPO_ROOT, ".skillspector-baseline.yaml")
SKILLS_DIR = os.path.join(REPO_ROOT, "roles", "dotfiles", "files", ".config", "copilot", "skills")

EXPECTED_SKILLS = [
    "artifact-generator",
    "conventional-commit",
    "test-coverage-auditor-py",
    "test-gap-closer-py",
    "test-generator",
    "test-standards-discovery",
]


class TestSkillSpectorE2E(unittest.TestCase):
    def setUp(self):
        self.env = os.environ.copy()
        self.env["PATH"] = f"{VENV_BIN}:{self.env.get('PATH', '')}"
        self.skillspector_bin = shutil.which("skillspector", path=self.env["PATH"]) or "skillspector"

    def test_01_all_six_skills_audited_in_bundle(self):
        """Test 1: Validate 100% component audit coverage across all 6 skills under direct non-recursive targeting."""
        for skill in EXPECTED_SKILLS:
            skill_md = os.path.join(SKILLS_DIR, skill, "SKILL.md")
            self.assertTrue(os.path.isfile(skill_md), f"Skill definition missing: {skill_md}")

        cmd = [
            self.skillspector_bin,
            "scan",
            SKILLS_DIR,
            "--baseline",
            BASELINE_PATH,
            "--no-llm",
            "--fail-on-findings",
        ]
        res = subprocess.run(cmd, cwd=REPO_ROOT, env=self.env, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Scan failed: {res.stdout}\n{res.stderr}")
        self.assertIn("Components (6)", res.stdout)
        for skill in EXPECTED_SKILLS:
            self.assertIn(f"{skill}/SKILL.md", res.stdout)

    def test_02_no_llm_flag_offline_determinism(self):
        """Test 2: Validate --no-llm enforcement ensuring zero external telemetry or LLM API dependencies."""
        clean_env = self.env.copy()
        for k in list(clean_env.keys()):
            if "API_KEY" in k or "TOKEN" in k:
                clean_env.pop(k)

        cmd = [
            self.skillspector_bin,
            "scan",
            SKILLS_DIR,
            "--baseline",
            BASELINE_PATH,
            "--no-llm",
            "--fail-on-findings",
        ]
        res = subprocess.run(cmd, cwd=REPO_ROOT, env=clean_env, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Inspection Completeness", res.stdout)
        self.assertIn("100.0%", res.stdout)

    def test_03_end_to_end_make_scan_skills(self):
        """Test 3: End-to-end execution of make scan-skills producing exit code 0 with active baseline."""
        res = subprocess.run(
            ["make", "scan-skills"],
            cwd=REPO_ROOT,
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, f"make scan-skills failed:\n{res.stdout}\n{res.stderr}")
        self.assertIn("Components (6)", res.stdout)
        self.assertIn("SAFE", res.stdout)


if __name__ == "__main__":
    unittest.main()
