#!/bin/bash
set -euo pipefail

LATTICE_DNS="snra-039a02be358d11929.rcfg-076bc848a5efc28a4.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo Testing DNS Resolution && getent hosts ${LATTICE_DNS} || echo DNS Resolution Failed && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task: ${TASK_ID}"
sleep 40
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 2m --format short
