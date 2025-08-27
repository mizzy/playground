START_TIME=$(date +%s)

echo "現在のインスタンス数を確認中..."
EXISTING_INSTANCES=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[*].DBInstanceIdentifier' \
  --output text)

INSTANCE_COUNT=$(echo $EXISTING_INSTANCES | wc -w)
echo "既存インスタンス数: $INSTANCE_COUNT"

echo "追加するインスタンスの識別子を設定中..."
ADDITIONAL_INSTANCES=""
for i in $(seq $INSTANCE_COUNT $((INSTANCE_COUNT * 2 - 1))); do
  if [ -z "$ADDITIONAL_INSTANCES" ]; then
    ADDITIONAL_INSTANCES="${CLUSTER_ID}-${i}"
  else
    ADDITIONAL_INSTANCES="$ADDITIONAL_INSTANCES ${CLUSTER_ID}-${i}"
  fi
done
echo "追加予定インスタンス: $ADDITIONAL_INSTANCES"

echo "既存インスタンスからパラメーターを取得中..."
REFERENCE_INSTANCE=$(echo $EXISTING_INSTANCES | awk '{print $1}')

INSTANCE_PARAMS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier $REFERENCE_INSTANCE \
  --query 'DBInstances[0]' \
  --output json)

ENGINE=$(echo $INSTANCE_PARAMS | jq -r '.Engine')
ENGINE_VERSION=$(echo $INSTANCE_PARAMS | jq -r '.EngineVersion')
AUTO_MINOR_VERSION=$(echo $INSTANCE_PARAMS | jq -r '.AutoMinorVersionUpgrade')
PUBLICLY_ACCESSIBLE=$(echo $INSTANCE_PARAMS | jq -r '.PubliclyAccessible')
MONITORING_INTERVAL=$(echo $INSTANCE_PARAMS | jq -r '.MonitoringInterval // 0')
MONITORING_ROLE_ARN=$(echo $INSTANCE_PARAMS | jq -r '.MonitoringRoleArn // empty')
PERFORMANCE_INSIGHTS=$(echo $INSTANCE_PARAMS | jq -r '.PerformanceInsightsEnabled')
PERFORMANCE_INSIGHTS_KMS=$(echo $INSTANCE_PARAMS | jq -r '.PerformanceInsightsKMSKeyId // empty')
PERFORMANCE_INSIGHTS_RETENTION=$(echo $INSTANCE_PARAMS | jq -r '.PerformanceInsightsRetentionPeriod // 7')
PARAMETER_GROUP=$(echo $INSTANCE_PARAMS | jq -r '.DBParameterGroups[0].DBParameterGroupName // empty')
CA_CERT=$(echo $INSTANCE_PARAMS | jq -r '.CACertificateIdentifier // empty')


echo "新しいインスタンスを作成中..."
for INSTANCE_ID in $ADDITIONAL_INSTANCES; do
  echo "インスタンス作成中: $INSTANCE_ID (参照元: $REFERENCE_INSTANCE)"

  CREATE_CMD="aws-vault exec mizzy -- aws rds create-db-instance"
  CREATE_CMD="$CREATE_CMD --db-instance-identifier $INSTANCE_ID"
  CREATE_CMD="$CREATE_CMD --db-cluster-identifier $CLUSTER_ID"
  CREATE_CMD="$CREATE_CMD --db-instance-class $TARGET_INSTANCE_CLASS"
  CREATE_CMD="$CREATE_CMD --engine $ENGINE"
  CREATE_CMD="$CREATE_CMD --engine-version $ENGINE_VERSION"
  CREATE_CMD="$CREATE_CMD --promotion-tier 0"

  if [ -n "$MONITORING_ROLE_ARN" ] && [ "$MONITORING_ROLE_ARN" != "empty" ]; then
    CREATE_CMD="$CREATE_CMD --monitoring-role-arn $MONITORING_ROLE_ARN --monitoring-interval $MONITORING_INTERVAL"
  fi

  if [ "$PERFORMANCE_INSIGHTS" = "true" ]; then
    CREATE_CMD="$CREATE_CMD --enable-performance-insights"
    if [ -n "$PERFORMANCE_INSIGHTS_KMS" ] && [ "$PERFORMANCE_INSIGHTS_KMS" != "empty" ]; then
      CREATE_CMD="$CREATE_CMD --performance-insights-kms-key-id $PERFORMANCE_INSIGHTS_KMS"
    fi
    CREATE_CMD="$CREATE_CMD --performance-insights-retention-period $PERFORMANCE_INSIGHTS_RETENTION"
  fi

  if [ -n "$PARAMETER_GROUP" ] && [ "$PARAMETER_GROUP" != "empty" ]; then
    CREATE_CMD="$CREATE_CMD --db-parameter-group-name $PARAMETER_GROUP"
  fi

  if [ -n "$CA_CERT" ] && [ "$CA_CERT" != "empty" ]; then
    CREATE_CMD="$CREATE_CMD --ca-certificate-identifier $CA_CERT"
  fi

  if [ "$AUTO_MINOR_VERSION" = "true" ]; then
    CREATE_CMD="$CREATE_CMD --auto-minor-version-upgrade"
  else
    CREATE_CMD="$CREATE_CMD --no-auto-minor-version-upgrade"
  fi

  if [ "$PUBLICLY_ACCESSIBLE" = "true" ]; then
    CREATE_CMD="$CREATE_CMD --publicly-accessible"
  else
    CREATE_CMD="$CREATE_CMD --no-publicly-accessible"
  fi

  eval $CREATE_CMD
done

echo "新しいインスタンスが利用可能になるのを待機中..."
WAIT_PIDS=""
for INSTANCE_ID in $ADDITIONAL_INSTANCES; do
  aws-vault exec mizzy -- aws rds wait db-instance-available --db-instance-identifier "${INSTANCE_ID}" &
  WAIT_PIDS="$WAIT_PIDS $!"
done
for PID in $WAIT_PIDS; do
  wait $PID
done

echo "追加インスタンスの作成が完了しました（同一パラメーター）"

echo ""
echo "=== 新しいインスタンスのパラメーター確認 ==="
for INSTANCE_ID in $ADDITIONAL_INSTANCES; do
  echo "インスタンス: $INSTANCE_ID"
  aws-vault exec mizzy -- aws rds describe-db-instances \
    --db-instance-identifier "${INSTANCE_ID}" \
    --query 'DBInstances[0].[DBInstanceClass,PerformanceInsightsEnabled,MonitoringInterval,AutoMinorVersionUpgrade]' \
    --output table
done

echo ""
TOTAL_COUNT=$((INSTANCE_COUNT * 2))
echo "=== 全インスタンスを含むクラスター（合計${TOTAL_COUNT}台） ==="
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier,IsClusterWriter]' \
  --output table

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
