#!/bin/bash

# Test accessing RDS Proxy via VPC Lattice DNS entry
CLUSTER_NAME="rds-client-cluster"
SUBNETS="subnet-099368fa8dc9ae0b0,subnet-0992567153552c401"
SECURITY_GROUP="sg-0aa93435a2043117b"
TASK_DEF="rds-proxy-test"
VPC_LATTICE_DNS="snra-0317e603085554c2e.rcfg-0e72a2deaf3ea0b99.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"

echo "=== Testing RDS Proxy via VPC Lattice DNS Entry ==="
echo ""

echo "Testing: $VPC_LATTICE_DNS"
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides "{
    \"containerOverrides\": [{
      \"name\": \"postgres-client\",
      \"command\": [\"bash\", \"-c\", \"PGPASSWORD=change-me-later psql -h $VPC_LATTICE_DNS -U postgres -d mydb -c \\\"SELECT current_user, inet_server_addr(), inet_server_port(), version();\\\"\"]
    }]
  }" \
  --query 'tasks[0].taskArn' --output text)

echo "Task ARN: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."
sleep 15

echo ""
echo "=== Checking CloudWatch Logs ==="
TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $NF}')
aws-vault exec rds-client -- aws logs get-log-events \
  --log-group-name /ecs/rds-client-tasks \
  --log-stream-name "postgres-test/postgres-client/$TASK_ID" \
  --query 'events[].message' \
  --output text
