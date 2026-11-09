.PHONY: help setup lint test-unit-ubuntu test-unit-amazonlinux test-unit test-e2e-ubuntu test-e2e-amazonlinux test-e2e test-smoke-ubuntu test-smoke-amazonlinux test-smoke test

help:
	@echo "Available commands:"
	@echo "  make setup                     - Installs the environment (requires Ansible)"
	@echo "  make lint                      - Runs pre-commit checks (ansible-lint, shellcheck, shfmt, stylua, luacheck)"
	@echo "  make test-unit-ubuntu          - Runs unit tests in Ubuntu container"
	@echo "  make test-unit-amazonlinux     - Runs unit tests in Amazon Linux container"
	@echo "  make test-unit                 - Runs unit tests across all supported distributions"
	@echo "  make test-e2e-ubuntu           - Runs e2e behavioral tests in Ubuntu container"
	@echo "  make test-e2e-amazonlinux      - Runs e2e behavioral tests in Amazon Linux container"
	@echo "  make test-e2e                  - Runs e2e behavioral tests across all supported distributions"
	@echo "  make test-smoke-ubuntu         - Runs smoke installation tests in Ubuntu container"
	@echo "  make test-smoke-amazonlinux    - Runs smoke installation tests in Amazon Linux container"
	@echo "  make test-smoke                - Runs smoke tests across all supported distributions"
	@echo "  make test                      - Runs all test categories sequentially in containers"

setup:
	ansible-playbook -i localhost, -c local setup.yml

lint:
	pre-commit run --all-files

test-unit-ubuntu:
	./tests/run.sh unit ubuntu:24.04

test-unit-amazonlinux:
	./tests/run.sh unit amazonlinux:2023

test-unit: test-unit-ubuntu test-unit-amazonlinux

test-e2e-ubuntu:
	./tests/run.sh e2e ubuntu:24.04

test-e2e-amazonlinux:
	./tests/run.sh e2e amazonlinux:2023

test-e2e: test-e2e-ubuntu test-e2e-amazonlinux

test-smoke-ubuntu:
	./tests/run.sh smoke ubuntu:24.04

test-smoke-amazonlinux:
	./tests/run.sh smoke amazonlinux:2023

test-smoke: test-smoke-ubuntu test-smoke-amazonlinux

test: test-unit test-e2e test-smoke
