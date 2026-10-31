.PHONY: help setup update test test-bootstrap test-bootstrap-unit test-bootstrap-smoke lint sync-nvim deps-bats

BATS ?= $(shell command -v bats 2>/dev/null || echo "tests/libs/bats-core/bin/bats")

help:
	@echo "Available commands:"
	@echo "  make setup          - Installs the environment (requires Ansible)"
	@echo "  make update         - Pulls latest version from Git and updates environment"
	@echo "  make sync-nvim      - Syncs ~/.config/nvim changes into monorepo (use SYNC_DELETE=1 to sync file deletions)"
	@echo "  make test           - Runs Molecule acceptance tests"
	@echo "  make test-bootstrap - Runs bootstrap unit tests and container smoke tests"
	@echo "  make lint           - Runs pre-commit and ansible-lint checks"

setup:
	ansible-playbook -i localhost, -c local setup.yml

update:
	@echo "=> Pulling latest infrastructure from Git..."
	git pull origin main
	@echo "=> Updating environment..."
	@$(MAKE) setup

# Sync changes made in ~/.config/nvim back into the monorepo.
# By default, modified/new files are synchronized without removing deleted files
# from the repository (to protect against accidental loss from partial local checkouts).
# To explicitly synchronize file deletions, pass SYNC_DELETE=1 (e.g., make sync-nvim SYNC_DELETE=1).
SYNC_DELETE ?= 0
RSYNC_DELETE_FLAG := $(if $(filter 1 true,$(SYNC_DELETE)),--delete,)

sync-nvim:
	@echo "=> Syncing ~/.config/nvim changes back to monorepo (deletions: $(if $(filter 1 true,$(SYNC_DELETE)),enabled,disabled))..."
	rsync -av $(RSYNC_DELETE_FLAG) \
		--exclude='.git*' \
		--exclude='.managed_manifest.json' \
		--exclude='*.swp' \
		--exclude='*.swo' \
		--exclude='*.swn' \
		--exclude='Session.vim' \
		--exclude='*.session' \
		--exclude='.env*' \
		--exclude='*.env' \
		--exclude='*.key' \
		--exclude='*.pem' \
		--exclude='*.cert' \
		--exclude='*.crt' \
		--exclude='*token*' \
		--exclude='*secret*' \
		--exclude='*credential*' \
		--exclude='id_rsa*' \
		--exclude='id_ed25519*' \
		--exclude='dap_config.lua' \
		--exclude='*.log' \
		--exclude='undo/' \
		--exclude='swap/' \
		--exclude='backup/' \
		--exclude='shada/' \
		$(HOME)/.config/nvim/ roles/nvim/files/nvim/

test:
	cd tests && molecule test

test-bootstrap-unit:
	@if [ ! -x "$$(command -v $(BATS) 2>/dev/null)" ] && [ ! -x "$(BATS)" ]; then \
		$(MAKE) deps-bats; \
	fi
	$(BATS) tests/test_bootstrap_logic.bats tests/test_bootstrap_packages.bats

test-bootstrap-smoke:
	@if [ ! -x "$$(command -v $(BATS) 2>/dev/null)" ] && [ ! -x "$(BATS)" ]; then \
		$(MAKE) deps-bats; \
	fi
	$(BATS) tests/test_bootstrap_containers.bats

test-bootstrap: test-bootstrap-unit test-bootstrap-smoke

lint:
	pre-commit run --all-files

deps-bats:
	@mkdir -p tests/libs
	@if [ ! -d "tests/libs/bats-core" ]; then \
		echo "=> Cloning bats-core..."; \
		git clone --depth 1 --branch v1.11.1 https://github.com/bats-core/bats-core.git tests/libs/bats-core; \
	fi
	@if [ ! -d "tests/libs/bats-support" ]; then \
		echo "=> Cloning bats-support..."; \
		git clone --depth 1 --branch v0.3.0 https://github.com/bats-core/bats-support.git tests/libs/bats-support; \
	fi
	@if [ ! -d "tests/libs/bats-assert" ]; then \
		echo "=> Cloning bats-assert..."; \
		git clone --depth 1 --branch v2.1.0 https://github.com/bats-core/bats-assert.git tests/libs/bats-assert; \
	fi
