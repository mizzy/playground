#!/bin/bash
set -e

# Get ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url)
REGION="ap-northeast-1"

echo "ECR Repository: $ECR_REPO"

# Login to ECR
echo "Logging in to ECR..."
aws-vault exec rds-client -- aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ECR_REPO"

# Build Docker image
echo "Building Docker image..."
docker build -t postgres-client .

# Tag image
echo "Tagging image..."
docker tag postgres-client:latest "$ECR_REPO:latest"

# Push image to ECR
echo "Pushing image to ECR..."
docker push "$ECR_REPO:latest"

echo "Done! Image pushed to $ECR_REPO:latest"
