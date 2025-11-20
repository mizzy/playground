#!/bin/bash
set -euo pipefail

# Pattern C VPC Lattice DNS名
LATTICE_DNS_PROXY_WRITER="snra-05c8959f3dedd93ed.rcfg-0c830603dadd13ccf.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_PROXY_READER="snra-0729f435aaa8c3406.rcfg-04ed74564b8ec0549.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

echo "=== Pattern C VPC Lattice DNS Resolution Test ==="
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

# Test RDS Proxy Writer Lattice DNS
echo "==> Testing RDS Proxy Writer Lattice DNS"
echo "DNS: ${LATTICE_DNS_PROXY_WRITER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'Pattern C RDS Proxy Writer DNS Test' && getent hosts ${LATTICE_DNS_PROXY_WRITER} || echo 'DNS Resolution Failed' && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | tail -10

echo ""
echo "==> Testing RDS Proxy Reader Lattice DNS"
echo "DNS: ${LATTICE_DNS_PROXY_READER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'Pattern C RDS Proxy Reader DNS Test' && getent hosts ${LATTICE_DNS_PROXY_READER} || echo 'DNS Resolution Failed' && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | tail -10

echo ""
echo "=== Test Complete ==="
