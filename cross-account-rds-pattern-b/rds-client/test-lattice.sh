#!/bin/bash
set -euo pipefail

LATTICE_DNS="snra-0de6b8780010962d7.rcfg-0c7d315913a607ec8.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

echo "=== Testing VPC Lattice DNS Connection ==="
echo "Lattice DNS: ${LATTICE_DNS}"
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "Subnets: ${SUBNET_IDS}"
echo "Security Group: ${SG_ID}"
echo ""

CMD="/bin/sh -c 'echo Testing Lattice DNS && PGPASSWORD=password123 psql -h ${LATTICE_DNS} -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && sleep 60'"

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo Testing Lattice DNS && PGPASSWORD=password123 psql -h '"${LATTICE_DNS}"' -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && sleep 60"]}]}' \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task started: ${TASK_ID}"
echo "Waiting 40 seconds..."
sleep 40

echo ""
echo "==> Results:"
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 2m --format short
