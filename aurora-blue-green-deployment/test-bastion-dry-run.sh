#!/bin/bash
# Dry run test for bastion-connect.sh

set -e

# Set test mode
export CLUSTER_NAME="aurora-bg-bastion-cluster"
export REGION="ap-northeast-1"
export AWS_PROFILE="mizzy"

echo "Testing bastion-connect.sh configuration..."
echo "============================================"

# Check AWS Vault
if ! command -v aws-vault &> /dev/null; then
    echo "ERROR: aws-vault is not installed"
    exit 1
fi
echo "✓ aws-vault is installed"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    exit 1
fi
echo "✓ AWS CLI is installed"

# Check jq
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed"
    exit 1
fi
echo "✓ jq is installed"

# Check ECS cluster
echo -n "Checking ECS cluster... "
CLUSTER_STATUS=$(aws-vault exec $AWS_PROFILE -- aws ecs describe-clusters \
    --cluster $CLUSTER_NAME \
    --region $REGION \
    --query 'clusters[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    echo "✓ Cluster is active"
else
    echo "✗ Cluster not found or not active: $CLUSTER_STATUS"
    exit 1
fi

# Check task definition
echo -n "Checking task definition... "
TASK_DEF_STATUS=$(aws-vault exec $AWS_PROFILE -- aws ecs describe-task-definition \
    --task-definition aurora-bg-bastion \
    --region $REGION \
    --query 'taskDefinition.status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TASK_DEF_STATUS" = "ACTIVE" ]; then
    echo "✓ Task definition is active"
else
    echo "✗ Task definition not found or not active: $TASK_DEF_STATUS"
    exit 1
fi

# Check Terraform outputs
echo -n "Checking Terraform outputs... "
SUBNETS=$(aws-vault exec $AWS_PROFILE -- terraform output -json private_subnets 2>/dev/null | jq -r '.[].id' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP=$(aws-vault exec $AWS_PROFILE -- terraform output -raw bastion_security_group_id 2>/dev/null)

if [ -n "$SUBNETS" ] && [ -n "$SECURITY_GROUP" ]; then
    echo "✓ Terraform outputs available"
    echo "  - Subnets: $SUBNETS"
    echo "  - Security Group: $SECURITY_GROUP"
else
    echo "⚠ Terraform outputs not available, checking AWS directly..."

    # Try to get from AWS
    VPC_ID=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=*aurora-bg*" \
        --region $REGION \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)

    if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
        SUBNETS=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" \
            --region $REGION \
            --query 'Subnets[].SubnetId' \
            --output text 2>/dev/null | tr '\t' ',')

        SECURITY_GROUP=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-security-groups \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*bastion*" \
            --region $REGION \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null)

        if [ -n "$SUBNETS" ] && [ -n "$SECURITY_GROUP" ] && [ "$SECURITY_GROUP" != "None" ]; then
            echo "✓ Configuration retrieved from AWS"
            echo "  - VPC: $VPC_ID"
            echo "  - Subnets: $SUBNETS"
            echo "  - Security Group: $SECURITY_GROUP"
        else
            echo "✗ Could not retrieve configuration from AWS"
            exit 1
        fi
    else
        echo "✗ Could not find VPC"
        exit 1
    fi
fi

# Test run-task command (dry run)
echo ""
echo "Testing task launch command (dry run)..."
echo "========================================="
echo "The following command would be executed:"
echo ""
echo "aws-vault exec $AWS_PROFILE -- aws ecs run-task \\"
echo "  --cluster $CLUSTER_NAME \\"
echo "  --task-definition aurora-bg-bastion \\"
echo "  --network-configuration \"awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}\" \\"
echo "  --enable-execute-command \\"
echo "  --launch-type FARGATE \\"
echo "  --region $REGION"
echo ""

# Check for existing service tasks
echo "Checking for existing service tasks..."
SERVICE_TASKS=$(aws-vault exec $AWS_PROFILE -- aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name aurora-bg-bastion-service \
    --region $REGION \
    --query 'taskArns' \
    --output json 2>/dev/null || echo "[]")

if [ "$SERVICE_TASKS" != "[]" ] && [ "$SERVICE_TASKS" != "null" ]; then
    TASK_COUNT=$(echo "$SERVICE_TASKS" | jq '. | length')
    echo "✓ Found $TASK_COUNT running service task(s)"
    echo "  You can connect to existing tasks with: ./bastion-connect.sh -s"
else
    echo "ℹ No service tasks running (service mode not enabled)"
fi

echo ""
echo "============================================"
echo "✅ All checks passed!"
echo ""
echo "You can now run:"
echo "  ./bastion-connect.sh        # Start new task and connect"
echo "  ./bastion-connect.sh -s     # Connect to existing service task"
echo "  ./bastion-connect.sh -h     # Show help"
