.PHONY: help setup lint test-unit test-e2e test-smoke test

help:
	@echo "Available commands:"
	@echo "  make setup       - Installs the environment (requires Ansible)"
	@echo "  make lint        - Runs pre-commit checks (ansible-lint, shellcheck, shfmt, stylua, luacheck)"
	@echo "  make test-unit   - Runs unit tests across all supported distributions"
	@echo "  make test-e2e    - Runs e2e behavioral tests across all supported distributions"
	@echo "  make test-smoke  - Runs smoke tests across all supported distributions"
	@echo "  make test        - Runs all test categories sequentially in containers"

setup:
	ansible-playbook -i localhost, -c local setup.yml

lint:
	pre-commit run --all-files

test-unit:
	./tests/run.sh unit ubuntu:24.04
	./tests/run.sh unit amazonlinux:2023

test-e2e:
	./tests/run.sh e2e ubuntu:24.04
	./tests/run.sh e2e amazonlinux:2023

test-smoke:
	./tests/run.sh smoke ubuntu:24.04
	./tests/run.sh smoke amazonlinux:2023

test: test-unit test-e2e test-smoke
