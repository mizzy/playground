#!/bin/bash
set -euo pipefail

ENDPOINT_TYPE="${1:-writer}"

if [ "${ENDPOINT_TYPE}" = "writer" ]; then
  DNS_NAME="pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
  ENDPOINT_NAME="RDS Proxy Writer (Private DNS)"
else
  DNS_NAME="pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
  ENDPOINT_NAME="RDS Proxy Reader (Private DNS)"
fi

echo "=== Pattern B Private DNS Connection Test ==="
echo "Testing: ${ENDPOINT_NAME}"
echo "DNS Name: ${DNS_NAME}"
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "Subnets: ${SUBNET_IDS}"
echo "Security Group: ${SG_ID}"
echo ""

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo Testing Private DNS && PGPASSWORD=password123 psql -h ${DNS_NAME} -U postgres -d testdb -c \\\"SELECT current_user, inet_server_addr(), version();\\\" && sleep 60\"]}]}" \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task started: ${TASK_ID}"
echo "Waiting 40 seconds..."
sleep 40

echo ""
echo "==> Results:"
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 2m --format short
