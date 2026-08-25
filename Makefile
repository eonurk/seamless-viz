.PHONY: r-backend service frontend dev kill-ports \
        up down logs build rebuild ps shell-r shell-service \
        download-assets check-assets docker-clean-cache docker-reset prod-build

# ---------------------------------------------------------------------------
# Docker (recommended -- see docs/DOCKER.md)
# ---------------------------------------------------------------------------

## Start the whole stack; builds images on first run.
up:
	docker compose up

## Same, detached.
up-d:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

## Build images without starting anything.
build:
	docker compose build

## Rebuild from scratch (after changing a Dockerfile or an env-*.yml).
rebuild:
	docker compose build --no-cache

## Verify the bind-mounted reference data and tool artifacts.
check-assets:
	./scripts/check-assets.sh

## Download and checksum the public AML reference dataset from OSF.
download-assets:
	./scripts/download-aml-assets.sh

shell-r:
	docker compose exec r-backend bash

shell-service:
	docker compose exec service bash

## Drop analysis caches (root-owned on Linux hosts, hence from inside).
docker-clean-cache:
	docker compose run --rm --no-deps --entrypoint sh r-backend \
	  -c 'rm -rf /app/backend/cache/*/ && echo "cache cleared (.reference kept)"'

## Nuke containers, named volumes and the compiled R library.
docker-reset:
	docker compose down -v

## Production-shaped images: prebuilt service dist + nginx-served frontend.
prod-build:
	SERVICE_TARGET=prod NODE_ENV=production docker compose build

# ---------------------------------------------------------------------------
# Native (requires micromamba seamless_env, Node, and the Python tool envs)
# ---------------------------------------------------------------------------

kill-ports:
	-lsof -ti :5555 | xargs kill -9 2>/dev/null
	-lsof -ti :3001 | xargs kill -9 2>/dev/null

r-backend:
	-lsof -ti :5555 | xargs kill -9 2>/dev/null
	./backend/start_r_backend.sh

service:
	-lsof -ti :3001 | xargs kill -9 2>/dev/null
	cd backend/service && npm start

frontend:
	cd vite-project && npm run dev

dev: kill-ports
	./backend/start_r_backend.sh & cd backend/service && npm start & cd vite-project && npm run dev
