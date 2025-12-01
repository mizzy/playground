.PHONY: build build-with-audit push login verify-arch all all-with-audit clean

# Variables
AWS_REGION := ap-northeast-1
ECR_REPO := distroless-audit
IMAGE_TAG := latest

# Docker build target: "base" (default) or "with-audit"
BUILD_TARGET ?= base

# Get AWS account ID and ECR URL
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO)

# Login to ECR
login:
	@echo "ECR にログイン中..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# Build for amd64 architecture (required for Fargate)
# Uses docker buildx to ensure correct architecture on M1/M2 Macs
build:
	@echo "amd64 アーキテクチャ用のイメージをビルド中... (target=$(BUILD_TARGET))"
	docker buildx build --platform linux/amd64 --target $(BUILD_TARGET) -t $(ECR_URL):$(IMAGE_TAG) --load .

# Build with audit logging enabled
build-with-audit:
	@$(MAKE) build BUILD_TARGET=with-audit

# Verify the image architecture before pushing
verify-arch:
	@echo "イメージのアーキテクチャを確認中..."
	@ARCH=$$(docker image inspect $(ECR_URL):$(IMAGE_TAG) --format '{{.Architecture}}'); \
	echo "Architecture: $$ARCH"; \
	if [ "$$ARCH" != "amd64" ]; then \
		echo "エラー: アーキテクチャが amd64 ではありません。Fargate で実行できません。"; \
		exit 1; \
	fi
	@echo "アーキテクチャ確認 OK: amd64"

# Push to ECR
push: verify-arch
	@echo "ECR にプッシュ中..."
	docker push $(ECR_URL):$(IMAGE_TAG)
	@echo "プッシュ完了: $(ECR_URL):$(IMAGE_TAG)"

# All-in-one: login, build, and push
all: login build push
	@echo "すべてのステップが完了しました"

# All-in-one with audit logging enabled
all-with-audit:
	@$(MAKE) all BUILD_TARGET=with-audit

# Clean up local images
clean:
	@echo "ローカルイメージを削除中..."
	-docker rmi $(ECR_URL):$(IMAGE_TAG)
