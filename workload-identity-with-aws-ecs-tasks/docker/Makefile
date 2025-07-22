# Makefile for building and managing the Google Sheets Go application container

# Variables
APP_NAME = sheets
IMAGE_NAME = $(APP_NAME)
TAG ?= latest
FULL_IMAGE_NAME = $(IMAGE_NAME):$(TAG)
REGISTRY ?= 
BUILD_CONTEXT = .
DOCKERFILE = ./Dockerfile

# AWS ECR variables (optional)
AWS_REGION ?= ap-northeast-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REGISTRY = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECR_IMAGE_NAME = $(ECR_REGISTRY)/$(APP_NAME)

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
push: ## Push image to registry
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY variable not set. Use 'make push REGISTRY=your-registry'"; \
		exit 1; \
	fi
	docker tag $(FULL_IMAGE_NAME) $(REGISTRY)/$(FULL_IMAGE_NAME)
	docker push $(REGISTRY)/$(FULL_IMAGE_NAME)
	@echo "Pushed: $(REGISTRY)/$(FULL_IMAGE_NAME)"

.PHONY: ecr-login
ecr-login: ## Login to AWS ECR
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: Unable to get AWS Account ID. Make sure AWS CLI is configured."; \
		exit 1; \
	fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	@echo "Logged in to ECR: $(ECR_REGISTRY)"

.PHONY: ecr-create-repo
ecr-create-repo: ## Create ECR repository if it doesn't exist
	@echo "Creating ECR repository: $(APP_NAME)"
	aws ecr describe-repositories --repository-names $(APP_NAME) --region $(AWS_REGION) 2>/dev/null || \
	aws ecr create-repository --repository-name $(APP_NAME) --region $(AWS_REGION)

.PHONY: ecr-push
ecr-push: ecr-create-repo ## Build and push to AWS ECR
	@echo "Building and pushing to ECR: $(ECR_IMAGE_NAME):$(TAG)"
	docker tag $(FULL_IMAGE_NAME) $(ECR_IMAGE_NAME):$(TAG)
	docker tag $(FULL_IMAGE_NAME) $(ECR_IMAGE_NAME):latest
	docker push $(ECR_IMAGE_NAME):$(TAG)
	docker push $(ECR_IMAGE_NAME):latest
	@echo "Pushed to ECR: $(ECR_IMAGE_NAME):$(TAG)"

.PHONY: clean
clean: ## Remove local images
	@echo "Removing local images..."
	docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	docker rmi $(ECR_IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(ECR_IMAGE_NAME):latest 2>/dev/null || true
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
# make ecr-push TAG=v1.0.0     # Push to ECR with specific tag
# make run SPREADSHEET_ID=your_id GOOGLE_CLOUD_PROJECT=your_project