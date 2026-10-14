.PHONY: help setup update test lint

help:
	@echo "Available commands:"
	@echo "  make setup   - Installs the environment (requires Ansible)"
	@echo "  make update  - Pulls latest version from Git and updates environment"
	@echo "  make test    - Runs Molecule acceptance tests"
	@echo "  make lint    - Runs pre-commit and ansible-lint checks"

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
