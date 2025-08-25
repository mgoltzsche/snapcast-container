##@ Interactive Testing

run-compose: ## Run docker compose project.
	make SKAFFOLD_OPTS='-t dev'
	docker compose up
