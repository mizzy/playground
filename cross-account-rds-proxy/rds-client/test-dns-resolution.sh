#!/bin/bash

# Get cluster and subnet info
CLUSTER_NAME="rds-client-cluster"
SUBNETS="subnet-099368fa8dc9ae0b0,subnet-0992567153552c401"
SECURITY_GROUP="sg-0aa93435a2043117b"
TASK_DEF="rds-proxy-test"

echo "=== Testing DNS Resolution ===" echo ""

echo "1. Resolving rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["nslookup", "rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
sleep 5
echo ""

echo "2. Resolving rds-proxy-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["nslookup", "rds-proxy-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
echo ""
echo "=== Tests initiated. Check CloudWatch Logs for results ===" echo "Log group: /ecs/rds-client-tasks"
