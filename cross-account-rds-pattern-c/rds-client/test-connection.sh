#!/bin/bash
set -euo pipefail

# Default to proxy-writer endpoint
ENDPOINT_TYPE="${1:-proxy-writer}"

echo "=== Pattern C RDS Proxy Connection Test ==="
echo "開始時刻: $(date)"
echo ""

# Set endpoint based on type
case "${ENDPOINT_TYPE}" in
  proxy-writer)
    ENDPOINT="pattern-c-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
    ENDPOINT_NAME="RDS Proxy Writer"
    ;;
  proxy-reader)
    ENDPOINT="pattern-c-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
    ENDPOINT_NAME="RDS Proxy Reader"
    ;;
  aurora-writer)
    ENDPOINT="pattern-c-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
    ENDPOINT_NAME="Aurora Cluster Writer"
    ;;
  aurora-reader)
    ENDPOINT="pattern-c-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"
    ENDPOINT_NAME="Aurora Cluster Reader"
    ;;
  all)
    echo "==> Running all endpoint tests..."
    for endpoint in proxy-writer proxy-reader aurora-writer aurora-reader; do
      echo ""
      echo "========================================"
      "$0" "${endpoint}"
      echo "========================================"
      echo ""
      sleep 5
    done
    exit 0
    ;;
  *)
    echo "Error: Invalid endpoint type."
    echo "Usage: $0 [proxy-writer|proxy-reader|aurora-writer|aurora-reader|all]"
    echo ""
    echo "  proxy-writer   - Test RDS Proxy Writer endpoint"
    echo "  proxy-reader   - Test RDS Proxy Reader endpoint"
    echo "  aurora-writer  - Test Aurora Cluster Writer endpoint"
    echo "  aurora-reader  - Test Aurora Cluster Reader endpoint"
    echo "  all            - Test all endpoints"
    exit 1
    ;;
esac

echo "Testing endpoint: ${ENDPOINT_NAME}"
echo "Endpoint: ${ENDPOINT}"
echo ""

# Get subnet and security group IDs
echo "==> Getting network configuration..."
SUBNET_IDS=$(aws-vault exec rds-client -- aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=pattern-c-private-*" \
  --query 'Subnets[].SubnetId' --output text | tr '\t' ',')

SG_ID=$(aws-vault exec rds-client -- aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=pattern-c-ecs-tasks-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

echo "Subnets: ${SUBNET_IDS}"
echo "Security Group: ${SG_ID}"
echo ""

# Run ECS task with connection test
echo "==> Running ECS task with connection test..."
TASK_ARN=$(aws-vault exec rds-client -- aws ecs run-task \
  --cluster pattern-c-test-cluster \
  --task-definition pattern-c-postgres-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SG_ID}],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"postgres-client\",\"command\":[\"/bin/sh\",\"-c\",\"echo 'Testing ${ENDPOINT_NAME} connection...' && PGPASSWORD=password123 psql -h ${ENDPOINT} -U postgres -d testdb -c 'SELECT current_user, inet_server_addr(), version();' && sleep 60\"]}]}" \
  --query 'tasks[0].taskArn' --output text)

TASK_ID=$(echo "${TASK_ARN}" | awk -F'/' '{print $NF}')
echo "Task started: ${TASK_ID}"
echo ""

# Wait for task to start and complete
echo "==> Waiting for task to complete (30 seconds)..."
sleep 30

# Get logs
echo "==> Connection test results:"
echo "----------------------------------------"
aws-vault exec rds-client -- aws logs tail /ecs/pattern-c-postgres-test --since 2m --format short
echo "----------------------------------------"
echo ""

echo "終了時刻: $(date)"
echo "=== Test Complete ==="
