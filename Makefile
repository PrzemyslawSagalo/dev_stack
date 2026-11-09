.PHONY: help setup lint test-nvim test-unit-ubuntu test-unit-amazonlinux test-unit test-smoke-ubuntu test-smoke-amazonlinux test-smoke test

help:
	@echo "Available commands:"
	@echo "  make setup                     - Installs the environment (requires Ansible)"
	@echo "  make lint                      - Runs pre-commit checks (ansible-lint, shellcheck, shfmt, stylua, luacheck)"
	@echo "  make test-nvim                 - Runs Neovim headless behavioral test suite"
	@echo "  make test-unit-ubuntu          - Runs unit tests in Ubuntu container"
	@echo "  make test-unit-amazonlinux     - Runs unit tests in Amazon Linux container"
	@echo "  make test-unit                 - Runs unit tests for all supported distributions"
	@echo "  make test-smoke-ubuntu         - Runs smoke installation test in Ubuntu container"
	@echo "  make test-smoke-amazonlinux    - Runs smoke installation test in Amazon Linux container"
	@echo "  make test-smoke                - Runs smoke tests for all supported distributions"
	@echo "  make test                      - Runs unit, smoke, and Neovim behavioral tests"

setup:
	ansible-playbook -i localhost, -c local setup.yml

lint:
	pre-commit run --all-files

test-nvim:
	XDG_CONFIG_HOME=$(CURDIR)/roles/nvim/files nvim --headless -c "PlenaryBustedDirectory tests/e2e/nvim {minimal_init = '$(CURDIR)/roles/nvim/files/nvim/init.lua'}"

test-unit-ubuntu:
	./tests/run.sh unit ubuntu:24.04

test-unit-amazonlinux:
	./tests/run.sh unit amazonlinux:2023

test-unit: test-unit-ubuntu test-unit-amazonlinux

test-smoke-ubuntu:
	./tests/run.sh smoke ubuntu:24.04

test-smoke-amazonlinux:
	./tests/run.sh smoke amazonlinux:2023

test-smoke: test-smoke-ubuntu test-smoke-amazonlinux

test: test-nvim test-unit test-smoke
