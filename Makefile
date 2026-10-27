.PHONY: help setup update test test-bootstrap lint sync-nvim

help:
	@echo "Available commands:"
	@echo "  make setup          - Installs the environment (requires Ansible)"
	@echo "  make update         - Pulls latest version from Git and updates environment"
	@echo "  make sync-nvim      - Syncs ~/.config/nvim changes into monorepo (use SYNC_DELETE=1 to sync file deletions)"
	@echo "  make test           - Runs Molecule acceptance tests"
	@echo "  make test-bootstrap - Runs bootstrap container smoke tests across AL2023, UBI9, and Ubuntu"
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

test-bootstrap:
	tests/test_bootstrap_logic.sh
	tests/test_bootstrap_packages.sh
	tests/test_bootstrap.sh

lint:
	pre-commit run --all-files
