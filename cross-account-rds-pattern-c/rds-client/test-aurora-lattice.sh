#!/bin/bash
set -euo pipefail

LATTICE_DNS_WRITER="snra-0b6b6dcea84dba545.rcfg-0d4aa8b99e08b7504.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_READER="snra-0249a74b7605c3f1d.rcfg-0c1ffd34e25449792.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

ENDPOINT_TYPE="${1:-writer}"

if [ "${ENDPOINT_TYPE}" = "writer" ]; then
  LATTICE_DNS="${LATTICE_DNS_WRITER}"
  ENDPOINT_NAME="Aurora Writer"
else
  LATTICE_DNS="${LATTICE_DNS_READER}"
  ENDPOINT_NAME="Aurora Reader"
fi

echo "=== Testing ${ENDPOINT_NAME} via Lattice DNS ==="
echo "Lattice DNS: ${LATTICE_DNS}"
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo Testing '"${ENDPOINT_NAME}"' && PGPASSWORD=password123 psql -h '"${LATTICE_DNS}"' -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && sleep 60"]}]}' \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task started: ${TASK_ID}"
echo "Waiting 40 seconds..."
sleep 40

echo ""
echo "==> Results:"
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 2m --format short
