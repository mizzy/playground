.PHONY: help terraform-init terraform-plan terraform-apply terraform-destroy docker-build docker-push ecr-login setup plan apply deploy destroy clean ecs-deploy ecs-status ecs-logs ecs-exec ecs-update ecs-run-monitor ecs-stop-monitor

# Variables
AWS_VAULT_PROFILE = mizzy
TERRAFORM_DIR = terraform
DOCKER_DIR = docker
ECSPRESSO_DIR = ecspresso
TAG ?= latest

# Default target
help:
	@echo "使用可能なコマンド:"
	@echo "  setup           - 初期セットアップ（terraform init）"
	@echo "  plan            - Terraformプランの表示"
	@echo "  apply           - Terraformの適用"
	@echo "  deploy          - インフラストラクチャのデプロイ"
	@echo "  destroy         - インフラストラクチャの削除"
	@echo "  docker-build    - Dockerイメージのビルド"
	@echo "  docker-push     - DockerイメージのECRプッシュ"
	@echo "  ecr-login       - ECRへのログイン"
	@echo "  ecs-deploy      - ECSサービスのデプロイ"
	@echo "  ecs-status      - ECSサービスの状態確認"
	@echo "  ecs-logs        - ECSサービスのログ表示"
	@echo "  ecs-exec        - ECSコンテナへの接続"
	@echo "  ecs-update      - ECSサービスの更新（イメージプッシュ＋デプロイ）"
	@echo "  ecs-run-monitor - DBモニタリングタスクの実行"
	@echo "  ecs-stop-monitor- DBモニタリングタスクの停止"
	@echo "  clean           - ローカルDockerイメージのクリーンアップ"
	@echo ""
	@echo "オプション:"
	@echo "  TAG=<version>   - Dockerイメージのタグを指定（デフォルト: latest）"

# Terraform operations
setup:
	@echo "Terraformの初期化を実行中..."
	cd $(TERRAFORM_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- terraform init

plan:
	@echo "Terraformプランを表示中..."
	cd $(TERRAFORM_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- terraform plan

apply:
	@echo "Terraformを適用中..."
	cd $(TERRAFORM_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- terraform apply

deploy: apply
	@echo "インフラストラクチャのデプロイ完了"

destroy:
	@echo "インフラストラクチャを削除中..."
	cd $(TERRAFORM_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- terraform destroy

# Docker operations
docker-build:
	@echo "Dockerイメージをビルド中..."
	cd $(DOCKER_DIR) && docker build --platform linux/amd64 -t aurora-failover-typescript-app:$(TAG) .

ecr-login:
	@echo "ECRにログイン中..."
	cd $(TERRAFORM_DIR) && \
	ECR_REPOSITORY_URL=$$(aws-vault exec $(AWS_VAULT_PROFILE) -- terraform output -raw ecr_repository_url) && \
	aws-vault exec $(AWS_VAULT_PROFILE) -- aws ecr get-login-password --region ap-northeast-1 | \
	docker login --username AWS --password-stdin $$ECR_REPOSITORY_URL

docker-push: docker-build ecr-login
	@echo "DockerイメージをECRにプッシュ中..."
	cd $(TERRAFORM_DIR) && \
	ECR_REPOSITORY_URL=$$(aws-vault exec $(AWS_VAULT_PROFILE) -- terraform output -raw ecr_repository_url) && \
	docker tag aurora-failover-typescript-app:$(TAG) $$ECR_REPOSITORY_URL:$(TAG) && \
	aws-vault exec $(AWS_VAULT_PROFILE) -- docker push $$ECR_REPOSITORY_URL:$(TAG) && \
	echo "✅ イメージのプッシュが完了しました!" && \
	echo "イメージURI: $$ECR_REPOSITORY_URL:$(TAG)"

# Utility operations
clean:
	@echo "ローカルDockerイメージをクリーンアップ中..."
	docker rmi -f aurora-failover-typescript-app:$(TAG) 2>/dev/null || true
	@echo "クリーンアップ完了"

# Combined operations
full-deploy: setup deploy docker-push
	@echo "🎉 フルデプロイメント完了!"

# ECS operations with ecspresso
ecs-deploy:
	@echo "ECSサービスをデプロイ中..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- ecspresso deploy --config ecspresso.yml

ecs-status:
	@echo "ECSサービスの状態を確認中..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- ecspresso status --config ecspresso.yml

ecs-logs:
	@echo "ECSサービスのログを表示中..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- ecspresso logs --config ecspresso.yml --follow

ecs-exec:
	@echo "ECSコンテナに接続中..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- ecspresso exec --config ecspresso.yml --container app -- /bin/bash

ecs-update: docker-push ecs-deploy
	@echo "🚀 ECSサービスの更新完了!"

# ECS monitoring operations
ecs-run-monitor:
	@echo "DBモニタリングタスクを実行中（リアルタイムログ表示）..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- ecspresso run --config ecspresso-monitor.yml --watch-container db-monitor

ecs-stop-monitor:
	@echo "DBモニタリングタスクを停止中..."
	cd $(ECSPRESSO_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- aws ecs list-tasks --cluster aurora-failover-test-cluster --family aurora-failover-db-monitor --query 'taskArns[0]' --output text | \
	xargs -I {} aws-vault exec $(AWS_VAULT_PROFILE) -- aws ecs stop-task --cluster aurora-failover-test-cluster --task {}

# Show terraform outputs
outputs:
	@echo "Terraform出力値:"
	cd $(TERRAFORM_DIR) && aws-vault exec $(AWS_VAULT_PROFILE) -- terraform output
