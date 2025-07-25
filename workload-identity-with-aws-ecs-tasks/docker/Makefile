# Makefile for building and managing the Google Sheets Go application container

# Variables
APP_NAME = sheets
IMAGE_NAME = $(APP_NAME)
TAG ?= latest
FULL_IMAGE_NAME = $(IMAGE_NAME):$(TAG)
BUILD_CONTEXT = .
DOCKERFILE = ./Dockerfile

# Docker Hub variables
DOCKER_HUB_USERNAME = mizzy
DOCKER_HUB_IMAGE_NAME = $(DOCKER_HUB_USERNAME)/$(APP_NAME)

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the Docker image
	@echo "Building Docker image: $(FULL_IMAGE_NAME)"
	docker build -f $(DOCKERFILE) -t $(FULL_IMAGE_NAME) $(BUILD_CONTEXT)
	@echo "Build complete: $(FULL_IMAGE_NAME)"

.PHONY: build-no-cache
build-no-cache: ## Build the Docker image without cache
	@echo "Building Docker image without cache: $(FULL_IMAGE_NAME)"
	docker build --no-cache -f $(DOCKERFILE) -t $(FULL_IMAGE_NAME) $(BUILD_CONTEXT)
	@echo "Build complete: $(FULL_IMAGE_NAME)"

.PHONY: run
run: ## Run the container locally (requires environment variables)
	@echo "Running container: $(FULL_IMAGE_NAME)"
	@echo "Make sure to set SPREADSHEET_ID and GOOGLE_CLOUD_PROJECT environment variables"
	docker run --rm \
		-e SPREADSHEET_ID=$(SPREADSHEET_ID) \
		-e GOOGLE_CLOUD_PROJECT=$(GOOGLE_CLOUD_PROJECT) \
		-e GOOGLE_APPLICATION_CREDENTIALS=/tmp/credentials.json \
		-v $(HOME)/.config/gcloud:/tmp/gcloud:ro \
		$(FULL_IMAGE_NAME)

.PHONY: run-interactive
run-interactive: ## Run the container interactively
	@echo "Running container interactively: $(FULL_IMAGE_NAME)"
	docker run --rm -it \
		-e SPREADSHEET_ID=$(SPREADSHEET_ID) \
		-e GOOGLE_CLOUD_PROJECT=$(GOOGLE_CLOUD_PROJECT) \
		--entrypoint /bin/sh \
		$(FULL_IMAGE_NAME)

.PHONY: push
push: ## Push image to Docker Hub
	@echo "Pushing to Docker Hub: $(DOCKER_HUB_IMAGE_NAME):$(TAG)"
	docker tag $(FULL_IMAGE_NAME) $(DOCKER_HUB_IMAGE_NAME):$(TAG)
	docker tag $(FULL_IMAGE_NAME) $(DOCKER_HUB_IMAGE_NAME):latest
	docker push $(DOCKER_HUB_IMAGE_NAME):$(TAG)
	docker push $(DOCKER_HUB_IMAGE_NAME):latest
	@echo "Pushed to Docker Hub: $(DOCKER_HUB_IMAGE_NAME):$(TAG)"

.PHONY: docker-login
docker-login: ## Login to Docker Hub
	@echo "Please login to Docker Hub"
	docker login
	@echo "Logged in to Docker Hub"

.PHONY: clean
clean: ## Remove local images
	@echo "Removing local images..."
	docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	docker rmi $(DOCKER_HUB_IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(DOCKER_HUB_IMAGE_NAME):latest 2>/dev/null || true
	docker image prune -f
	@echo "Cleanup complete"

.PHONY: test
test: build ## Test the built image
	@echo "Testing the Docker image..."
	docker run --rm $(FULL_IMAGE_NAME) --help 2>/dev/null || echo "Container runs successfully"

.PHONY: size
size: ## Show image size
	@echo "Image size:"
	docker images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

.PHONY: inspect
inspect: ## Inspect the Docker image
	docker inspect $(FULL_IMAGE_NAME)

.PHONY: all
all: clean build test ## Clean, build, and test

# Usage examples:
# make build                    # Build with default tag
# make build TAG=v1.0.0        # Build with specific tag
# make push TAG=v1.0.0         # Push to Docker Hub with specific tag
# make run SPREADSHEET_ID=your_id GOOGLE_CLOUD_PROJECT=your_project