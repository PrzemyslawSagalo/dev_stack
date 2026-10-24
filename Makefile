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
	rsync -av \
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

lint:
	pre-commit run --all-files
