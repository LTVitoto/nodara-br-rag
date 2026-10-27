# Nodara BR-RAG · atajos operativos (Docker Compose v2)
SHELL := /bin/bash
-include .env
export

COMPOSE ?= docker compose
FRONTEND_PORT ?= 3000
n ?= 5

.DEFAULT_GOAL := help
.PHONY: help env preflight config up down ps logs models embed kb-seed simulate smoke ui-test reset-data clean
DATA_VOLUMES := s4hana-data vector-data kafka-data minio-data unity-catalog-db

help: ## Lista los comandos disponibles
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

env: ## Crea .env desde .env.example con secretos aleatorios (no sobrescribe)
	@./scripts/init-env.sh

preflight: ## Detecta colisiones de puertos en el host (Linux/WSL + Windows)
	@./scripts/preflight.sh

config: ## Valida la sintaxis y la interpolación del docker-compose
	@$(COMPOSE) config --quiet && echo "docker-compose válido"

up: env preflight ## Construye y levanta el stack completo (espera a que esté healthy)
	$(COMPOSE) up -d --build
	@./scripts/wait-healthy.sh

down: ## Detiene el stack (conserva los volúmenes)
	$(COMPOSE) down

ps: ## Estado y salud de los contenedores
	@$(COMPOSE) ps -a --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'

logs: ## Sigue logs (ej.: make logs s=delta-sink)
	$(COMPOSE) logs -f --tail=100 $(s)

models: ## Importa LLM + embeddings al enclave vía uplink controlado (air-gap)
	$(COMPOSE) --profile bootstrap run --rm ollama-bootstrap

embed: ## Indexa los manuales en pgvector con embeddings locales
	@curl -fsS -X POST http://127.0.0.1:$(FRONTEND_PORT)/api/kb/embed && echo

kb-seed: ## Regenera el seed de pgvector desde knowledge/ (originales + curación)
	@python3 scripts/build-kb-seed.py

simulate: ## Genera actividad SAP en S/4 para ver el CDC (ej.: make simulate n=10)
	@$(COMPOSE) exec -T s4hana-db psql -U "$(S4_DB_ADMIN_USER)" -d s4hana -c "SELECT * FROM sap.simulate_activity($(n));"

smoke: ## QA E2E: salud, CDC→Delta, raw layer + linaje, federación Trino, KB, IA y air-gap
	@./scripts/smoke-test.sh

ui-test: ## QA UI: selector de idioma ES/EN/PT con Playwright (perfil qa)
	$(COMPOSE) --profile qa run --rm --build --no-deps ui-test

reset-data: ## Re-siembra desde cero: borra volúmenes de datos (conserva modelos Ollama)
	$(COMPOSE) down --remove-orphans
	-docker volume rm $(addprefix nodara-br-rag_,$(DATA_VOLUMES))

clean: ## Detiene y BORRA todos los volúmenes, incluidos los modelos (reset total)
	$(COMPOSE) down -v --remove-orphans
