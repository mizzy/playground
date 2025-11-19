#!/bin/bash
set -euo pipefail

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-b-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

echo "Running DNS resolution test..."

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-b-test-cluster \
  --task-definition pattern-b-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"postgres-client","command":["/bin/sh","-c","echo === Writer DNS === && nslookup pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com && echo === Reader DNS === && nslookup pattern-b-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com && echo === Service Network Endpoint IPs === && echo 10.0.2.122 10.0.1.223 && sleep 60"]}]}' \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task started: ${TASK_ID}"
echo "Waiting 30 seconds..."
sleep 30

echo ""
echo "==> DNS resolution results:"
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --since 2m --format short
