#!/bin/bash

set -euo pipefail

# Variables
AWS_REGION="ap-northeast-1"
IMAGE_NAME="aurora-failover-typescript-app"
TAG="${1:-latest}"

echo "ECRリポジトリへのDockerイメージビルドとプッシュを開始します..."

# Get ECR repository URL from Terraform output
echo "TerraformからECRリポジトリURLを取得中..."
cd ../terraform
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
echo "ECRリポジトリURL: ${ECR_REPOSITORY_URL}"

# Go back to docker directory
cd ../docker

# Login to ECR
echo "ECRにログイン中..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}

# Build Docker image
echo "Dockerイメージをビルド中..."
docker build -t ${IMAGE_NAME}:${TAG} .

# Tag image for ECR
echo "ECR用にイメージをタグ付け中..."
docker tag ${IMAGE_NAME}:${TAG} ${ECR_REPOSITORY_URL}:${TAG}

# Push image to ECR
echo "ECRにイメージをプッシュ中..."
docker push ${ECR_REPOSITORY_URL}:${TAG}

echo "✅ イメージのプッシュが完了しました!"
echo "イメージURI: ${ECR_REPOSITORY_URL}:${TAG}"
