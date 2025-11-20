#!/bin/bash
set -euo pipefail

# 最新のVPC Lattice DNS名
LATTICE_DNS_PROXY_WRITER="snra-0d19a30c5128a9982.rcfg-0824c6814b9373689.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_PROXY_READER="snra-07b66972b0e51b9ea.rcfg-0045a2f984e67c28e.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_AURORA_WRITER="snra-07f0dd0d612c3d145.rcfg-0163a0e6fcb9eb1f7.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_AURORA_READER="snra-08d8c4907200ec254.rcfg-092a6e19eb1ded941.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

echo "=== VPC Lattice DNS Resolution Test ==="
echo ""

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

# Test RDS Proxy Writer Lattice DNS
echo "==> Testing RDS Proxy Writer Lattice DNS Resolution"
echo "DNS: ${LATTICE_DNS_PROXY_WRITER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'RDS Proxy Writer Lattice DNS Resolution' && getent hosts ${LATTICE_DNS_PROXY_WRITER} && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | grep -A 5 "RDS Proxy Writer"

echo ""
echo "==> Testing RDS Proxy Reader Lattice DNS Resolution"
echo "DNS: ${LATTICE_DNS_PROXY_READER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'RDS Proxy Reader Lattice DNS Resolution' && getent hosts ${LATTICE_DNS_PROXY_READER} && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | grep -A 5 "RDS Proxy Reader"

echo ""
echo "==> Testing Aurora Writer Lattice DNS Resolution"
echo "DNS: ${LATTICE_DNS_AURORA_WRITER}"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'Aurora Writer Lattice DNS Resolution' && getent hosts ${LATTICE_DNS_AURORA_WRITER} && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 35
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | grep -A 5 "Aurora Writer"

echo ""
echo "=== Test Complete ==="
