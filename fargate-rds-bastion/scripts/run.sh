#!/bin/bash
set -e

export ECSPRESSO_DEBUG=false

SCRIPT_DIR="$(dirname "$0")"
ECSPRESSO_DIR="$SCRIPT_DIR/../ecspresso"

echo "タスクを起動中..."
ecspresso run --config "$ECSPRESSO_DIR/ecspresso.yml" --wait-until=running > /dev/null 2>&1

echo ""
echo "Aurora接続情報："
echo "  Host: fargate-rds-bastion-cluster.cluster-c0kiz503n2ut.ap-northeast-1.rds.amazonaws.com"
echo "  Port: 5432"
echo "  User: dbadmin"
echo "  Database: mydb"
echo ""
echo "psqlコマンド例："
echo "  psql -h fargate-rds-bastion-cluster.cluster-c0kiz503n2ut.ap-northeast-1.rds.amazonaws.com -U dbadmin -d mydb"
