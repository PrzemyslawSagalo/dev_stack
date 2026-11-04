.PHONY: help setup update lint test-unit-ubuntu test-unit-amazonlinux test-unit test-smoke-ubuntu test-smoke-amazonlinux test-smoke test

help:
	@echo "Available commands:"
	@echo "  make setup                     - Installs the environment (requires Ansible)"
	@echo "  make update                    - Pulls latest version from Git and updates environment"
	@echo "  make lint                      - Runs pre-commit and ansible-lint checks"
	@echo "  make test-unit-ubuntu          - Runs unit tests in Ubuntu container"
	@echo "  make test-unit-amazonlinux     - Runs unit tests in Amazon Linux container"
	@echo "  make test-unit                 - Runs unit tests for all supported distributions"
	@echo "  make test-smoke-ubuntu         - Runs smoke installation test in Ubuntu container"
	@echo "  make test-smoke-amazonlinux    - Runs smoke installation test in Amazon Linux container"
	@echo "  make test-smoke                - Runs smoke tests for all supported distributions"
	@echo "  make test                      - Runs unit and smoke tests"

setup:
	ansible-playbook -i localhost, -c local setup.yml

update:
	@echo "=> Pulling latest infrastructure from Git..."
	git pull origin main
	@echo "=> Updating environment..."
	@$(MAKE) setup

lint:
	pre-commit run --all-files

test-unit-ubuntu:
	./tests/run.sh unit ubuntu:22.04

test-unit-amazonlinux:
	./tests/run.sh unit amazonlinux:2023

test-unit: test-unit-ubuntu test-unit-amazonlinux

test-smoke-ubuntu:
	./tests/run.sh smoke ubuntu:22.04

test-smoke-amazonlinux:
	./tests/run.sh smoke amazonlinux:2023

test-smoke: test-smoke-ubuntu test-smoke-amazonlinux

test: test-unit test-smoke
