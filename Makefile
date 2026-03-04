.PHONY: help docker-build docker-test docker-run docker-clean clean

PORT ?= 8080

help: ## Show this help message
	@echo "cl-battlesnake Docker Commands"
	@echo "==============================="
	@echo ""
	@echo "  make docker-build    Build Docker image"
	@echo "  make docker-test     Build and test Docker image"
	@echo "  make docker-run      Run Docker container locally on port $(PORT)"
	@echo "  make docker-clean    Remove Docker images and containers"
	@echo "  make clean           Clean all build artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make docker-run PORT=3000"

docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t cl-battlesnake .
	@echo "✅ Image built successfully"

docker-test: docker-build ## Build and test Docker image
	@echo "Running Docker tests..."
	./test-docker.sh

docker-run: docker-build ## Run Docker container locally
	@echo "Starting multi-snake container on port $(PORT)..."
	@echo "Snakes available at:"
	@echo "  http://localhost:$(PORT)/random/"
	@echo "  http://localhost:$(PORT)/hungry/"
	@echo "  http://localhost:$(PORT)/cautious/"
	@echo ""
	@echo "Press Ctrl+C to stop"
	docker run --rm -p $(PORT):8080 cl-battlesnake

docker-clean: ## Clean up Docker images and containers
	@echo "Cleaning up Docker resources..."
	-docker stop $$(docker ps -q --filter ancestor=cl-battlesnake) 2>/dev/null || true
	-docker rm $$(docker ps -aq --filter ancestor=cl-battlesnake) 2>/dev/null || true
	-docker rmi cl-battlesnake 2>/dev/null || true
	@echo "✅ Cleanup complete"

clean: docker-clean ## Clean up all build artifacts
	@echo "Cleaning up build artifacts..."
	find . -name "*.fasl" -delete
	find . -name "*.fas" -delete
	@echo "✅ All build artifacts removed"
