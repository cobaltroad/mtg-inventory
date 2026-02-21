.PHONY: help up up-prod down logs logs-prod

help:
	@echo "Usage:"
	@echo "  make up        - Start development environment"
	@echo "  make up-prod  - Start production environment"
	@echo "  make down     - Stop all containers"
	@echo "  make logs     - View development logs"
	@echo "  make logs-prod - View production logs"

up:
	docker compose up -d

up-prod:
	APP_ENV=production VITE_AUTH_ENABLED=true docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

logs-prod:
	APP_ENV=production docker compose logs -f
