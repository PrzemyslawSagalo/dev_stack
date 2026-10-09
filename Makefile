.PHONY: help setup update

help:
	@echo "Dostępne komendy:"
	@echo "  make setup   - Instaluje środowisko (wymaga zainstalowanego Ansible)"
	@echo "  make update  - Pobiera najnowszą wersję z Git i aktualizuje środowisko"

setup:
	ansible-playbook -i localhost, -c local setup.yml

update:
	@echo "=> Pobieranie najnowszej infrastruktury z Git..."
	git pull origin main
	@echo "=> Aktualizacja środowiska..."
	@$(MAKE) setup
