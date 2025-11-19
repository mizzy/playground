#!/bin/bash

# Get subnet IDs and security group
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-c-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ',')
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "Starting test task..."
echo "Subnets: $SUBNET_IDS"
echo "Security Group: $SG_ID"

# Run the test task
TASK_ARN=$(aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-rds-proxy-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Test task started: $TASK_ARN"
echo "Waiting for task to complete (60 seconds)..."
sleep 60

# Get the task ID
TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')

echo "Fetching logs from CloudWatch..."
aws logs tail /ecs/pattern-c-postgres-test --follow --since 3m --format short
