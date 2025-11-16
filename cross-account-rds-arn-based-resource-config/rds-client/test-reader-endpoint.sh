#!/bin/bash
set -e

echo "Testing Aurora Reader Endpoint connection through Service Network..."

# Run ECS task with reader endpoint test command
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster rds-client-cluster \
  --task-definition postgres-client \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-019cc093387101089,subnet-0072294e15e6b689e],securityGroups=[sg-0df658fd636014a01]}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"sh\",\"-c\",\"echo 'Testing READER endpoint connection...' && PGPASSWORD=password123 psql -h aurora-cluster-arn-based.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c 'SELECT version();' && echo 'SUCCESS: Reader endpoint connection worked!' || echo 'FAILED: Reader endpoint connection failed'\"],\"environment\":[{\"name\":\"TEST_RUN\",\"value\":\"reader\"}]}]}" \
  --query 'tasks[0].taskArn' \
  --output text)

# Extract task ID from ARN
TASK_ID=$(echo "$TASK_ARN" | awk -F/ '{print $NF}')
echo "Started task: $TASK_ID"

# Wait for task to complete
echo "Waiting for task to complete..."
aws-vault exec rds-client -- aws ecs wait tasks-stopped --cluster rds-client-cluster --tasks "$TASK_ID"

echo "Task completed. Checking exit code..."
aws-vault exec rds-client -- aws ecs describe-tasks --cluster rds-client-cluster --tasks "$TASK_ID" --query 'tasks[0].{exitCode:containers[0].exitCode,stoppedReason:stoppedReason}' --output json

echo ""
echo "Checking logs..."
sleep 5

# Get logs
aws-vault exec rds-client -- aws logs tail /ecs/rds-client-tasks --since 5m --format short | grep -E "(READER|SUCCESS|FAILED|version|PostgreSQL)" | tail -10
