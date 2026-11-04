.PHONY: help setup update lint test-smoke-ubuntu test-smoke-amazonlinux test-smoke

help:
	@echo "Available commands:"
	@echo "  make setup                     - Installs the environment (requires Ansible)"
	@echo "  make update                    - Pulls latest version from Git and updates environment"
	@echo "  make lint                      - Runs pre-commit and ansible-lint checks"
	@echo "  make test-smoke-ubuntu         - Runs smoke installation test in Ubuntu container"
	@echo "  make test-smoke-amazonlinux    - Runs smoke installation test in Amazon Linux container"
	@echo "  make test-smoke                - Runs smoke tests for all supported distributions"

setup:
	ansible-playbook setup.yml

update:
	@echo "=> Pulling latest infrastructure from Git..."
	git pull origin main
	@echo "=> Updating environment..."
	@$(MAKE) setup

lint:
	pre-commit run --all-files

test-smoke-ubuntu:
	./tests/test_smoke/run_smoke_test.sh ubuntu:22.04

test-smoke-amazonlinux:
	./tests/test_smoke/run_smoke_test.sh amazonlinux:2023

test-smoke: test-smoke-ubuntu test-smoke-amazonlinux
