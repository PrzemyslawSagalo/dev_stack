.PHONY: help setup update test lint scan-skills

help:
	@echo "Available commands:"
	@echo "  make setup       - Installs the environment (requires Ansible)"
	@echo "  make update      - Pulls latest version from Git and updates environment"
	@echo "  make test        - Runs Molecule acceptance tests"
	@echo "  make lint        - Runs pre-commit and ansible-lint checks"
	@echo "  make scan-skills - Scans AI agent skills for security vulnerabilities with SkillSpector"

setup:
	ansible-playbook -i localhost, -c local setup.yml

update:
	@echo "=> Pulling latest infrastructure from Git..."
	git pull origin main
	@echo "=> Updating environment..."
	@$(MAKE) setup

test:
	cd tests && molecule test

lint:
	pre-commit run --all-files

scan-skills:
	@command -v skillspector >/dev/null 2>&1 || which skillspector >/dev/null 2>&1 || (echo "Please install skillspector: pip install git+https://github.com/NVIDIA/SkillSpector.git@v2.12.0" && exit 1)
	skillspector scan roles/dotfiles/files/.config/copilot/skills --baseline .skillspector-baseline.yaml --no-llm --fail-on-findings

