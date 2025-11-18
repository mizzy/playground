#!/bin/bash

# Get cluster and subnet info
CLUSTER_NAME="rds-client-cluster"
SUBNETS="subnet-099368fa8dc9ae0b0,subnet-0992567153552c401"
SECURITY_GROUP="sg-0aa93435a2043117b"
TASK_DEF="rds-proxy-test"

echo "=== Testing Resource Endpoint Connections ==="
echo ""

# Test 1: Aurora Cluster direct access via Resource Endpoint
echo "1. Testing Aurora Cluster (direct)..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["bash", "-c", "PGPASSWORD=change-me-later psql -h rds-proxy-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d mydb -c \"SELECT current_user, inet_server_addr(), inet_server_port(), version();\""]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
sleep 5
echo ""

# Test 2: RDS Proxy (write endpoint) via Resource Endpoint
echo "2. Testing RDS Proxy (write endpoint)..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["bash", "-c", "PGPASSWORD=change-me-later psql -h rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d mydb -c \"SELECT current_user, inet_server_addr(), inet_server_port(), version();\""]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
sleep 5
echo ""

# Test 3: RDS Proxy Reader endpoint via Resource Endpoint
echo "3. Testing RDS Proxy Reader endpoint..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["bash", "-c", "PGPASSWORD=change-me-later psql -h rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d mydb -c \"SELECT current_user, inet_server_addr(), inet_server_port(), version();\""]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
echo ""
echo "=== Tests initiated. Check CloudWatch Logs for results ==="
echo "Log group: /ecs/rds-client-tasks"
