#!/bin/bash
set -euo pipefail

# 元のRDS Proxy DNS名
ORIGINAL_DNS_WRITER="pattern-c-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
ORIGINAL_DNS_READER="pattern-c-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "=== Pattern C - Original RDS Proxy DNS Name Test ==="
echo ""
echo "==> Testing RDS Proxy Writer with Original DNS Name"
echo "DNS: ${ORIGINAL_DNS_WRITER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'RDS Proxy Writer - Original DNS' && getent ahosts ${ORIGINAL_DNS_WRITER} | grep STREAM && echo '' && echo 'Connection Test:' && PGPASSWORD=password123 psql -h ${ORIGINAL_DNS_WRITER} -U postgres -d testdb -c 'SELECT current_user, inet_server_addr(), version();' && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 40
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 2m --format short

echo ""
echo "==> Testing RDS Proxy Reader with Original DNS Name"
echo "DNS: ${ORIGINAL_DNS_READER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'RDS Proxy Reader - Original DNS' && getent ahosts ${ORIGINAL_DNS_READER} | grep STREAM && echo '' && echo 'Connection Test:' && PGPASSWORD=password123 psql -h ${ORIGINAL_DNS_READER} -U postgres -d testdb -c 'SELECT current_user, inet_server_addr(), pg_is_in_recovery();' && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 40
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 2m --format short

echo ""
echo "=== Test Complete ==="
