#!/bin/bash
set -e

export ECSPRESSO_DEBUG=false

SCRIPT_DIR="$(dirname "$0")"
ECSPRESSO_DIR="$SCRIPT_DIR/../ecspresso"

CLUSTER="fargate-rds-bastion-cluster"
CONTAINER="bastion"

# Check if a task is already running
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --desired-status RUNNING --query 'taskArns[0]' --output text)

if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
    echo "起動中のタスクがありません。新しいタスクを起動します..."
    ecspresso run --config "$ECSPRESSO_DIR/ecspresso.yml" --wait-until=running > /dev/null 2>&1
    TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --desired-status RUNNING --query 'taskArns[0]' --output text)
    echo "ECS Execエージェントの準備を待機中..."
    sleep 10
fi

TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
echo "Task ID: $TASK_ID"
echo "コンテナに接続します..."

aws ecs execute-command \
    --cluster "$CLUSTER" \
    --task "$TASK_ID" \
    --container "$CONTAINER" \
    --interactive \
    --command /bin/bash
