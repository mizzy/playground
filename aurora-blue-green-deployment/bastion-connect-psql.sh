#!/bin/bash
set -e

# デフォルト値の設定
CLUSTER_NAME="${CLUSTER_NAME:-aurora-bg-bastion-cluster}"
REGION="${REGION:-ap-northeast-1}"
AWS_PROFILE="${AWS_PROFILE:-mizzy}"

# カラー出力用の設定
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting ECS Bastion Task for PostgreSQL connection...${NC}"

# Terraformから値を取得
echo "Getting configuration from Terraform outputs..."
SUBNETS=$(aws-vault exec $AWS_PROFILE -- terraform output -json private_subnets 2>/dev/null | jq -r '.[].id' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP=$(aws-vault exec $AWS_PROFILE -- terraform output -raw bastion_security_group_id 2>/dev/null)

if [ -z "$SUBNETS" ] || [ -z "$SECURITY_GROUP" ]; then
    echo -e "${RED}Error: Could not get values from Terraform outputs.${NC}"
    exit 1
fi

echo "Subnets: $SUBNETS"
echo "Security Group: $SECURITY_GROUP"

# タスクを起動
echo "Starting task..."
TASK_ARN=$(aws-vault exec $AWS_PROFILE -- aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition aurora-bg-bastion \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
    --enable-execute-command \
    --launch-type FARGATE \
    --region $REGION \
    --query 'tasks[0].taskArn' \
    --output text 2>/dev/null)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo -e "${RED}Failed to start task${NC}"
    exit 1
fi

echo -e "${GREEN}Task started: $TASK_ARN${NC}"
echo "Waiting for task to be ready (this may take up to 60 seconds)..."

# タスクが実行中になるまで待機
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(aws-vault exec $AWS_PROFILE -- aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARN \
        --region $REGION \
        --query 'tasks[0].lastStatus' \
        --output text 2>/dev/null)

    if [ "$STATUS" = "RUNNING" ]; then
        # Wait for ExecuteCommandAgent to be ready
        AGENT_STATUS=$(aws-vault exec $AWS_PROFILE -- aws ecs describe-tasks \
            --cluster $CLUSTER_NAME \
            --tasks $TASK_ARN \
            --region $REGION \
            --query 'tasks[0].containers[0].managedAgents[0].lastStatus' \
            --output text 2>/dev/null)

        if [ "$AGENT_STATUS" = "RUNNING" ]; then
            echo ""
            echo "Agent is running, waiting additional 30 seconds for full initialization..."
            sleep 30
            break
        fi
    elif [ "$STATUS" = "STOPPED" ]; then
        REASON=$(aws-vault exec $AWS_PROFILE -- aws ecs describe-tasks \
            --cluster $CLUSTER_NAME \
            --tasks $TASK_ARN \
            --region $REGION \
            --query 'tasks[0].stoppedReason' \
            --output text 2>/dev/null)
        echo -e "${RED}Task stopped unexpectedly: $REASON${NC}"
        exit 1
    fi

    echo -n "."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${RED}Timeout waiting for task to start${NC}"
    aws-vault exec $AWS_PROFILE -- aws ecs stop-task --cluster $CLUSTER_NAME --task $TASK_ARN --region $REGION > /dev/null 2>&1
    exit 1
fi

echo ""
echo -e "${GREEN}Task is ready!${NC}"
echo -e "${GREEN}Connecting to PostgreSQL...${NC}"
echo ""
echo "========================================="
echo "Connected to Aurora PostgreSQL"
echo "Type SQL commands or \\q to quit"
echo "========================================="
echo ""

# PostgreSQLに直接接続
aws-vault exec $AWS_PROFILE -- aws ecs execute-command \
    --cluster $CLUSTER_NAME \
    --task $TASK_ARN \
    --container bastion \
    --interactive \
    --command "/usr/bin/psql" \
    --region $REGION

# 接続終了後、タスクを停止
echo ""
echo -e "${YELLOW}Stopping task...${NC}"
aws-vault exec $AWS_PROFILE -- aws ecs stop-task \
    --cluster $CLUSTER_NAME \
    --task $TASK_ARN \
    --region $REGION \
    --output text > /dev/null 2>&1

echo -e "${GREEN}Task stopped successfully${NC}"
