#!/bin/bash
set -euo pipefail

LATTICE_DNS="${1:-snra-0de6b8780010962d7.rcfg-0c7d315913a607ec8.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws}"
ENDPOINT_NAME="${2:-RDS Proxy Writer (Lattice DNS)}"

echo "=== Pattern B VPC Lattice DNS Connection Test ==="
echo "開始時刻: $(date)"
echo ""
echo "Testing endpoint: ${ENDPOINT_NAME}"
echo "Lattice DNS: ${LATTICE_DNS}"
echo ""

SUBNETS=$(terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SECURITY_GROUP=$(terraform output -json | jq -r '.vpc_id.value' | xargs -I {} aws ec2 describe-security-groups --filters "Name=vpc-id,Values={}" "Name=group-name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "==> Getting network configuration..."
echo "Subnets: ${SUBNETS}"
echo "Security Group: ${SECURITY_GROUP}"
echo ""

echo "==> Running ECS task with connection test..."
TASK_ARN=$(aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUP}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"environment\":[{\"name\":\"DB_HOST\",\"value\":\"${LATTICE_DNS}\"},{\"name\":\"DB_PORT\",\"value\":\"5432\"},{\"name\":\"DB_USER\",\"value\":\"postgres\"},{\"name\":\"DB_PASSWORD\",\"value\":\"password123\"},{\"name\":\"DB_NAME\",\"value\":\"postgres\"}]}]}" \
  --query 'tasks[0].taskArn' \
  --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F/ '{print $NF}')
echo "Task started: ${TASK_ID}"
echo ""

echo "==> Waiting for task to complete (30 seconds)..."
sleep 30

echo "==> Connection test results:"
echo "----------------------------------------"
aws logs tail /ecs/pattern-b-postgres-test --since 1m --format short --filter-pattern "Testing" 2>/dev/null || true
echo "----------------------------------------"
echo ""

echo "終了時刻: $(date)"
echo "=== Test Complete ==="
