#!/bin/bash
set -euo pipefail

ORIGINAL_DNS="pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "=== Pattern B Custom Domain Name Test ==="
echo ""
echo "Testing: RDS Proxy Writer with Original DNS Name"
echo "DNS: ${ORIGINAL_DNS}"
echo "Subnets: ${SUBNET_IDS}"
echo "Security Group: ${SG_ID}"
echo ""

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'DNS Resolution Test:' && getent ahosts ${ORIGINAL_DNS} && echo '' && echo 'Connection Test:' && PGPASSWORD=password123 psql -h ${ORIGINAL_DNS} -U postgres -d testdb -c 'SELECT current_user, inet_server_addr(), version();' && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)

echo "Task started: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
echo "Waiting 40 seconds..."
sleep 40

echo ""
echo "=== Task Logs ==="
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 2m --format short
echo ""
echo "=== Test Complete ==="
