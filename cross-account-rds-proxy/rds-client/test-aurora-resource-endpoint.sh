#!/bin/bash

# Test accessing Aurora Cluster via Resource Endpoint using standard DNS name
CLUSTER_NAME="rds-client-cluster"
SUBNETS="subnet-099368fa8dc9ae0b0,subnet-0992567153552c401"
SECURITY_GROUP="sg-0aa93435a2043117b"
TASK_DEF="rds-proxy-test"

echo "=== Testing Aurora Cluster via Resource Endpoint (Standard DNS Name) ==="
echo ""

echo "Testing Writer: rds-proxy-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["bash", "-c", "PGPASSWORD=change-me-later psql -h rds-proxy-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d mydb -c \"SELECT '\''Writer Endpoint'\'' as endpoint, current_user, inet_server_addr(), inet_server_port(), version();\""]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."
sleep 15

echo ""
echo "=== Checking CloudWatch Logs ===="
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $NF}')
aws-vault exec rds-client -- aws logs get-log-events \
  --log-group-name /ecs/rds-client-tasks \
  --log-stream-name "postgres-test/postgres-client/$TASK_ID" \
  --query 'events[].message' \
  --output text

echo ""
echo ""
echo "=== Testing Reader: rds-proxy-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com ==="
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "postgres-client",
      "command": ["bash", "-c", "PGPASSWORD=change-me-later psql -h rds-proxy-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d mydb -c \"SELECT '\''Reader Endpoint'\'' as endpoint, current_user, inet_server_addr(), inet_server_port(), version();\""]
    }]
  }' \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."
sleep 15

echo ""
echo "=== Checking CloudWatch Logs ===="
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $NF}')
aws-vault exec rds-client -- aws logs get-log-events \
  --log-group-name /ecs/rds-client-tasks \
  --log-stream-name "postgres-test/postgres-client/$TASK_ID" \
  --query 'events[].message' \
  --output text
