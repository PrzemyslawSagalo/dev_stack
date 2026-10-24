.PHONY: help setup update test lint sync-nvim

help:
	@echo "Available commands:"
	@echo "  make setup     - Installs the environment (requires Ansible)"
	@echo "  make update    - Pulls latest version from Git and updates environment"
	@echo "  make sync-nvim - Syncs ~/.config/nvim changes back into monorepo"
	@echo "  make test      - Runs Molecule acceptance tests"
	@echo "  make lint      - Runs pre-commit and ansible-lint checks"

setup:
	ansible-playbook -i localhost, -c local setup.yml

update:
	@echo "=> Pulling latest infrastructure from Git..."
	git pull origin main
	@echo "=> Updating environment..."
	@$(MAKE) setup

sync-nvim:
	@echo "=> Syncing ~/.config/nvim changes back to monorepo..."
	rsync -av --delete --exclude='.git' --exclude='lazy-lock.json' --exclude='.managed_manifest.json' --exclude='*.swp' --exclude='*.swo' --exclude='*.swn' --exclude='Session.vim' --exclude='*.session' $(HOME)/.config/nvim/ roles/nvim/files/nvim/

test:
	cd tests && molecule test

lint:
	pre-commit run --all-files
