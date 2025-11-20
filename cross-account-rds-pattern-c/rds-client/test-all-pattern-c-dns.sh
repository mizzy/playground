#!/bin/bash
set -euo pipefail

LATTICE_DNS_PROXY_WRITER="snra-05c8959f3dedd93ed.rcfg-0c830603dadd13ccf.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_PROXY_READER="snra-0729f435aaa8c3406.rcfg-04ed74564b8ec0549.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_AURORA_WRITER="snra-0249a74b7605c3f1d.rcfg-0c1ffd34e25449792.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"
LATTICE_DNS_AURORA_READER="snra-0b6b6dcea84dba545.rcfg-0d4aa8b99e08b7504.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

SUBNET_IDS=$(aws-vault exec rds-client -- terraform output -json subnet_ids | jq -r '.[]' | paste -sd "," -)
SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text)

TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo '=== RDS Proxy Writer ===' && getent ahosts ${LATTICE_DNS_PROXY_WRITER} | grep STREAM && echo '' && echo '=== RDS Proxy Reader ===' && getent ahosts ${LATTICE_DNS_PROXY_READER} | grep STREAM && echo '' && echo '=== Aurora Writer ===' && getent ahosts ${LATTICE_DNS_AURORA_WRITER} | grep STREAM && echo '' && echo '=== Aurora Reader ===' && getent ahosts ${LATTICE_DNS_AURORA_READER} | grep STREAM && sleep 30\"]}]}" \
  --query 'tasks[0].taskArn' --output text)

echo "Task: $(echo ${TASK_ARN} | awk -F'/' '{print $NF}')"
echo "Waiting for logs..."
sleep 40
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 2m --format short
