#!/bin/bash
set -e

echo "=== Lambda Workload Identity Deployment ==="

# Get the Lambda role ARN from Terraform output
echo "Getting Lambda role ARN from Terraform..."
cd ../terraform
LAMBDA_ROLE_ARN=$(terraform output -raw lambda_workload_identity_role_arn 2>/dev/null || echo "")

if [ -z "$LAMBDA_ROLE_ARN" ]; then
    echo "Error: Lambda role ARN not found. Please run 'terraform apply' in the terraform directory first."
    exit 1
fi

cd ../lambroll

echo "Lambda Role ARN: $LAMBDA_ROLE_ARN"

# Build TypeScript
echo "Building TypeScript..."
npm run build

# Export the role ARN for lambroll
export LAMBDA_ROLE_ARN

# Deploy with lambroll
echo "Deploying Lambda function..."
lambroll deploy

echo "Deployment complete!"