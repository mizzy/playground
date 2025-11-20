#!/bin/bash
set -euo pipefail

echo "=== RDS Proxy Connection Test (No Private DNS) ==="
echo "Testing RDS Proxy with dns_resource.domain_name only"
echo "customDomainName: null"
echo "privateDnsEnabled: false"
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "==> Testing RDS Proxy Writer DNS Resolution"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo RDS Proxy Writer DNS Test && getent hosts pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com && sleep 30"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "==> Testing RDS Proxy Writer Connection"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo RDS Proxy Writer Connection Test && timeout 30 bash -c \"PGPASSWORD=password123 psql -h pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \\\"SELECT 1\\\"\" || echo Connection timed out && sleep 10"]}]}' \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 45
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short | tail -5

echo ""
echo "=== Test Complete ==="
