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

# ヘルプメッセージ
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Connect to Aurora PostgreSQL via ECS Bastion Task"
    echo ""
    echo "Options:"
    echo "  -c, --cluster NAME    ECS cluster name (default: aurora-bg-bastion-cluster)"
    echo "  -r, --region REGION   AWS region (default: ap-northeast-1)"
    echo "  -p, --profile PROFILE AWS Vault profile (default: mizzy)"
    echo "  -s, --service         Connect to existing service task instead of creating new one"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  CLUSTER_NAME         ECS cluster name"
    echo "  REGION              AWS region"
    echo "  AWS_PROFILE         AWS Vault profile"
}

# オプション解析
SERVICE_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# AWS CLIの存在確認
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# AWS Vaultの存在確認
if ! command -v aws-vault &> /dev/null; then
    echo -e "${RED}Error: aws-vault is not installed${NC}"
    echo "Please install aws-vault: brew install aws-vault (macOS)"
    exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Terraformの存在確認（SERVICE_MODEでない場合のみ）
if [ "$SERVICE_MODE" = false ] && ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# サービスモードの処理
if [ "$SERVICE_MODE" = true ]; then
    echo -e "${GREEN}Connecting to existing ECS service task...${NC}"

    SERVICE_NAME="aurora-bg-bastion-service"

    # サービスから実行中のタスクを取得
    TASK_ARN=$(aws-vault exec $AWS_PROFILE -- aws ecs list-tasks \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --region $REGION \
        --query 'taskArns[0]' \
        --output text 2>/dev/null)

    if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
        echo -e "${RED}No running tasks found for service $SERVICE_NAME${NC}"
        echo "Make sure the service is running with: terraform apply -var='bastion_enable_service=true'"
        exit 1
    fi

    echo -e "${GREEN}Found task: $TASK_ARN${NC}"
    echo -e "${GREEN}Connecting to task...${NC}"
    echo "Type 'psql' to connect to PostgreSQL"
    echo "Type 'exit' to disconnect (task will continue running)"

    # タスクに接続
    aws-vault exec $AWS_PROFILE -- aws ecs execute-command \
        --cluster $CLUSTER_NAME \
        --task $TASK_ARN \
        --container bastion \
        --interactive \
        --command "/bin/sh" \
        --region $REGION

    echo -e "${GREEN}Disconnected from service task (task remains running)${NC}"
    exit 0
fi

# ワンタイムタスクモード
echo -e "${GREEN}Starting ECS Bastion Task...${NC}"

# Terraformから値を取得
echo "Getting configuration from Terraform outputs..."

# Terraformの初期化状態をチェック
if ! aws-vault exec $AWS_PROFILE -- terraform output -json 2>&1 | grep -q "private_subnets"; then
    # エラーメッセージを確認
    ERROR_MSG=$(aws-vault exec $AWS_PROFILE -- terraform output -json 2>&1)
    if echo "$ERROR_MSG" | grep -q "Backend initialization required"; then
        echo -e "${RED}Error: Terraform is not initialized in this directory.${NC}"
        echo -e "${YELLOW}Please run: aws-vault exec $AWS_PROFILE -- terraform init${NC}"
        exit 1
    elif echo "$ERROR_MSG" | grep -q "No outputs found"; then
        echo -e "${RED}Error: No Terraform outputs found.${NC}"
        echo -e "${YELLOW}Please run: aws-vault exec $AWS_PROFILE -- terraform apply${NC}"
        exit 1
    fi
fi

SUBNETS=$(aws-vault exec $AWS_PROFILE -- terraform output -json private_subnets 2>/dev/null | jq -r '.[].id' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP=$(aws-vault exec $AWS_PROFILE -- terraform output -raw bastion_security_group_id 2>/dev/null)

if [ -z "$SUBNETS" ] || [ -z "$SECURITY_GROUP" ]; then
    echo -e "${YELLOW}Warning: Could not get values from Terraform outputs.${NC}"
    echo "Trying to get values from AWS..."

    # VPCを検索
    VPC_ID=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=*aurora-bg*" \
        --region $REGION \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)

    if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
        # サブネットを検索
        SUBNETS=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" \
            --region $REGION \
            --query 'Subnets[].SubnetId' \
            --output text 2>/dev/null | tr '\t' ',')

        # セキュリティグループを検索
        SECURITY_GROUP=$(aws-vault exec $AWS_PROFILE -- aws ec2 describe-security-groups \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*bastion*" \
            --region $REGION \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null)
    fi

    if [ -z "$SUBNETS" ] || [ -z "$SECURITY_GROUP" ] || [ "$SECURITY_GROUP" = "None" ]; then
        echo -e "${RED}Error: Could not determine network configuration.${NC}"
        echo "Please ensure you have run 'terraform apply' first."
        exit 1
    fi
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
    echo "Please check that the ECS cluster and task definition exist."
    exit 1
fi

echo -e "${GREEN}Task started: $TASK_ARN${NC}"
echo "Waiting for task to be ready (this may take up to 60 seconds)..."

# タスクが実行中になるまで待機（タイムアウト付き）
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
            # Additional wait to ensure agent is fully initialized
            echo ""
            echo "Agent is running, waiting additional 20 seconds for full initialization..."
            sleep 20
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
echo -e "${GREEN}Connecting to task...${NC}"
echo ""
echo "========================================="
echo "Type 'psql' to connect to PostgreSQL"
echo "Type 'exit' to disconnect and stop the task"
echo "========================================="
echo ""

# タスクに接続
aws-vault exec $AWS_PROFILE -- aws ecs execute-command \
    --cluster $CLUSTER_NAME \
    --task $TASK_ARN \
    --container bastion \
    --interactive \
    --command "/bin/sh" \
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
