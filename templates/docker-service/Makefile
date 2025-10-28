.PHONY: build up down logs

build:
	@docker compose build

up:
	@docker compose up --detach

logs:
	@docker compose logs -f

down:
	@docker compose down --remove-orphans
