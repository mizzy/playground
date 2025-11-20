#!/bin/bash
set -euo pipefail

LATTICE_DNS="snra-05c8959f3dedd93ed.rcfg-0c830603dadd13ccf.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

echo "=== Pattern C VPC Lattice DNS IPv4 Resolution Test ==="

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'IPv4/IPv6 DNS Test' && getent hosts ${LATTICE_DNS} && echo '--- dig A record ---' && dig +short ${LATTICE_DNS} A && echo '--- dig AAAA record ---' && dig +short ${LATTICE_DNS} AAAA && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)
echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
sleep 40
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 1m --format short | tail -20
