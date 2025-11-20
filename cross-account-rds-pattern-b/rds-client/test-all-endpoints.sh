#!/bin/bash
set -euo pipefail

echo "=== Pattern B - Complete Database Connection Test ==="
echo "Testing all Aurora and RDS Proxy endpoints"
echo ""

# Get subnet and security group info
SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

# Test Aurora Writer
echo "==> Testing Aurora Writer"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo Aurora Writer Test && PGPASSWORD=password123 psql -h pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && sleep 30"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "==> Testing Aurora Reader"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo Aurora Reader Test && PGPASSWORD=password123 psql -h pattern-b-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), pg_is_in_recovery();\" && sleep 30"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "==> Testing RDS Proxy Writer"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo RDS Proxy Writer Test && PGPASSWORD=password123 psql -h pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && sleep 30"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "==> Testing RDS Proxy Reader"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo RDS Proxy Reader Test && PGPASSWORD=password123 psql -h pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), pg_is_in_recovery();\" && sleep 30"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "=== Test Complete ==="
