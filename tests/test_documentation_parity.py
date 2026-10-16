import os
import subprocess
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MAKEFILE_PATH = os.path.join(REPO_ROOT, "Makefile")
README_PATH = os.path.join(REPO_ROOT, "README.md")


class TestDocumentationParity(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.path.isfile(MAKEFILE_PATH), f"Makefile missing at {MAKEFILE_PATH}")
        self.assertTrue(os.path.isfile(README_PATH), f"README.md missing at {README_PATH}")
        with open(MAKEFILE_PATH, "r") as f:
            self.makefile_content = f.read()
        with open(README_PATH, "r") as f:
            self.readme_content = f.read()

    def test_01_makefile_help_recipe_contains_scan_skills(self):
        """Test 1: Verify make help recipe in Makefile includes scan-skills entry."""
        self.assertIn("scan-skills", self.makefile_content)
        lines = self.makefile_content.splitlines()
        help_lines = []
        in_help = False
        for line in lines:
            if line.startswith("help:"):
                in_help = True
                continue
            if in_help:
                if line.strip() == "" or (line and not line.startswith("\t") and not line.startswith(" ")):
                    break
                help_lines.append(line)

        help_block = "\n".join(help_lines)
        self.assertIn("scan-skills", help_block)

    def test_02_make_help_runtime_output(self):
        """Test 2: Verify executing make help prints make scan-skills with descriptive help text."""
        res = subprocess.run(
            ["make", "help"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, f"make help failed with output: {res.stdout}\n{res.stderr}")
        self.assertIn("scan-skills", res.stdout)
        self.assertIn("SkillSpector", res.stdout)

    def test_03_readme_operational_shortcuts_lists_scan_skills(self):
        """Test 3: Verify README.md Section 2 (Operational Shortcuts) lists make scan-skills with explanation of AI agent skill security scanning."""
        self.assertIn("make scan-skills", self.readme_content)
        self.assertIn("SkillSpector", self.readme_content)

    def test_04_readme_makefile_link_and_formatting(self):
        """Test 4: Verify README.md markdown link to Makefile remains intact and formatting matches existing targets."""
        self.assertIn("Makefile", self.readme_content)
        self.assertIn("make setup", self.readme_content)
        self.assertIn("make update", self.readme_content)
        self.assertIn("make test", self.readme_content)
        self.assertIn("make lint", self.readme_content)


if __name__ == "__main__":
    unittest.main()
