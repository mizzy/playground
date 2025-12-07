#!/bin/bash
set -e

export ECSPRESSO_DEBUG=false

SCRIPT_DIR="$(dirname "$0")"
ECSPRESSO_DIR="$SCRIPT_DIR/../ecspresso"

CLUSTER="fargate-rds-bastion-cluster"
CONTAINER="bastion"
LOCAL_PORT="${1:-5432}"
REMOTE_HOST="fargate-rds-bastion-cluster.cluster-c0kiz503n2ut.ap-northeast-1.rds.amazonaws.com"
REMOTE_PORT="5432"

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

# Get container runtime ID
RUNTIME_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ID" --query 'tasks[0].containers[0].runtimeId' --output text)

echo "Task ID: $TASK_ID"
echo "Runtime ID: $RUNTIME_ID"
echo ""
echo "ポートフォワードを開始します..."
echo "  ローカル: localhost:$LOCAL_PORT"
echo "  リモート: $REMOTE_HOST:$REMOTE_PORT"
echo ""
echo "別のターミナルから以下のコマンドで接続できます："
echo "  psql -h localhost -p $LOCAL_PORT -U dbadmin -d mydb"
echo ""
echo "終了するには Ctrl+C を押してください"
echo ""

aws ssm start-session \
    --target "ecs:${CLUSTER}_${TASK_ID}_${RUNTIME_ID}" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$REMOTE_HOST\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}"
