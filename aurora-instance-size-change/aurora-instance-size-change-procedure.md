# Aurora インスタンスサイズ変更手順書

## 概要
本手順書では、Aurora PostgreSQL クラスターのインスタンスサイズを、フェイルオーバー時の30秒〜1分のダウンタイムのみで変更する方法を説明します。
新しいサイズのインスタンスを既存と同数追加し、その後古いインスタンスを削除することで、ダウンタイムを最小化します。

## 前提条件
- AWS CLI がインストールされ、適切な権限で設定されていること
- Aurora クラスターが既に稼働していること
- 最低1つのインスタンスが存在すること
- 一時的にインスタンス数が倍になるため、コスト増加を許容できること

## 詳細手順

### ステップ1: シェル変数の設定

作業に必要な変数を設定します。

#### 実行コマンド
```bash
CLUSTER_ID="aurora-size-test-aurora"
CURRENT_INSTANCE_CLASS="db.t4g.medium"
TARGET_INSTANCE_CLASS="db.r7g.large"
```

#### 確認項目
- [ ] CLUSTER_IDが正しく設定されていること
- [ ] CURRENT_INSTANCE_CLASSが現在のインスタンスクラスと一致すること
- [ ] TARGET_INSTANCE_CLASSが変更後のインスタンスクラスであること

### ステップ2: 現在の状態確認

現在のクラスター構成とインスタンスの状態を確認します。

#### 実行コマンド
```bash
ORIGINAL_WRITER=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
  --output text)

ORIGINAL_READER=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`false`].DBInstanceIdentifier' \
  --output text | head -n1)

echo "ORIGINAL_WRITER: $ORIGINAL_WRITER"
echo "ORIGINAL_READER: $ORIGINAL_READER"
```

#### 期待される出力例
```
ORIGINAL_WRITER: aurora-size-test-aurora-0
ORIGINAL_READER: aurora-size-test-aurora-1
```

#### 確認項目
- [ ] ORIGINAL_WRITERがWriterインスタンスのIDと一致すること
- [ ] ORIGINAL_READERがReaderインスタンスのIDと一致すること

### ステップ3: 新しいサイズのインスタンスを追加

TARGET_INSTANCE_CLASSで指定したサイズの新しいインスタンスを既存と同数追加します。既存インスタンスと同じパラメーターを使用します。

#### 3.1: 既存インスタンスのパラメーター取得

現在稼働中のインスタンスからパラメーターを取得し、追加するインスタンスの設定を準備します。

##### 実行コマンド

```bash
EXISTING_INSTANCES=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[*].DBInstanceIdentifier' \
  --output text)

INSTANCE_COUNT=$(echo "$EXISTING_INSTANCES" | wc -w)

ADDITIONAL_INSTANCES=""
for i in $(seq "$INSTANCE_COUNT" $((INSTANCE_COUNT * 2 - 1))); do
  if [ -z "$ADDITIONAL_INSTANCES" ]; then
    ADDITIONAL_INSTANCES="${CLUSTER_ID}-${i}"
  else
    ADDITIONAL_INSTANCES="$ADDITIONAL_INSTANCES ${CLUSTER_ID}-${i}"
  fi
done

REFERENCE_INSTANCE=$(echo "$EXISTING_INSTANCES" | awk '{print $1}')

INSTANCE_PARAMS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$REFERENCE_INSTANCE" \
  --query 'DBInstances[0]' \
  --output json)

ENGINE=$(echo "$INSTANCE_PARAMS" | jq -r '.Engine')
ENGINE_VERSION=$(echo "$INSTANCE_PARAMS" | jq -r '.EngineVersion')
AUTO_MINOR_VERSION=$(echo "$INSTANCE_PARAMS" | jq -r '.AutoMinorVersionUpgrade')
PUBLICLY_ACCESSIBLE=$(echo "$INSTANCE_PARAMS" | jq -r '.PubliclyAccessible')
MONITORING_INTERVAL=$(echo "$INSTANCE_PARAMS" | jq -r '.MonitoringInterval // 0')
MONITORING_ROLE_ARN=$(echo "$INSTANCE_PARAMS" | jq -r '.MonitoringRoleArn // empty')
PERFORMANCE_INSIGHTS=$(echo "$INSTANCE_PARAMS" | jq -r '.PerformanceInsightsEnabled')
PERFORMANCE_INSIGHTS_KMS=$(echo "$INSTANCE_PARAMS" | jq -r '.PerformanceInsightsKMSKeyId // empty')
PERFORMANCE_INSIGHTS_RETENTION=$(echo "$INSTANCE_PARAMS" | jq -r '.PerformanceInsightsRetentionPeriod // 7')
PARAMETER_GROUP=$(echo "$INSTANCE_PARAMS" | jq -r '.DBParameterGroups[0].DBParameterGroupName // empty')
CA_CERT=$(echo "$INSTANCE_PARAMS" | jq -r '.CACertificateIdentifier // empty')

INSTANCE_TAGS=$(aws-vault exec mizzy -- aws rds list-tags-for-resource \
  --resource-name "arn:aws:rds:${AWS_DEFAULT_REGION:-ap-northeast-1}:$(aws-vault exec mizzy -- aws sts get-caller-identity --query Account --output text):db:$REFERENCE_INSTANCE" \
  --query 'TagList' \
  --output json)
TAG_COUNT=$(echo "$INSTANCE_TAGS" | jq '. | length')

echo ""
echo "既存インスタンス: $EXISTING_INSTANCES"
echo "追加予定インスタンス: $ADDITIONAL_INSTANCES"
echo ""
echo "参照元インスタンス: $REFERENCE_INSTANCE"
echo "ENGINE: $ENGINE"
echo "ENGINE_VERSION: $ENGINE_VERSION"
echo "PARAMETER_GROUP: $PARAMETER_GROUP"
echo "AUTO_MINOR_VERSION_UPGRADE: $AUTO_MINOR_VERSION"
echo "CA_CERTIFICATE: $CA_CERT"
echo "PERFORMANCE_INSIGHTS_ENABLED: $PERFORMANCE_INSIGHTS"
if [ "$PERFORMANCE_INSIGHTS" = "true" ]; then
  echo "PERFORMANCE_INSIGHTS_RETENTION: $PERFORMANCE_INSIGHTS_RETENTION"
fi
echo ""
echo "タグ:"
if [ "$TAG_COUNT" -gt 0 ]; then
  echo "$INSTANCE_TAGS" | jq -r '.[] | "  \(.Key): \(.Value)"'
else
  echo "  (なし)"
fi
```

##### 期待される出力例
```
既存インスタンス: aurora-size-test-aurora-0 aurora-size-test-aurora-1
追加予定インスタンス: aurora-size-test-aurora-2 aurora-size-test-aurora-3

参照元インスタンス: aurora-size-test-aurora-0
ENGINE: aurora-postgresql
ENGINE_VERSION: 15.4
PARAMETER_GROUP: default.aurora-postgresql15
AUTO_MINOR_VERSION_UPGRADE: false
CA_CERTIFICATE: rds-ca-rsa4096-g1
PERFORMANCE_INSIGHTS_ENABLED: true
PERFORMANCE_INSIGHTS_RETENTION: 7

タグ:
  Environment: test
  Purpose: aurora-instance-size-change
```

##### 確認項目
- [ ] 既存インスタンスのIDが正しく表示されていること
- [ ] 追加予定インスタンスのIDが既存インスタンス数と同数生成されていること
- [ ] パラメーターが正常に取得されていること
- [ ] タグが正しく表示されていること

#### 3.2: 新しいインスタンスの作成

取得したパラメーターを使用して、新しいサイズのインスタンスを作成します。

##### 実行コマンド

```bash
echo "新しいインスタンスを作成中..."
echo "$ADDITIONAL_INSTANCES" | tr ' ' '\n' | while read -r INSTANCE_ID; do
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

  if [ "$TAG_COUNT" -gt 0 ]; then
    CREATE_CMD="$CREATE_CMD --tags '$INSTANCE_TAGS'"
  fi

  eval "$CREATE_CMD" > /dev/null
done

echo "インスタンス作成コマンドが正常に実行されました"
```

##### 期待される出力例
```
新しいインスタンスを作成中...
インスタンス作成中: aurora-size-test-aurora-2 (参照元: aurora-size-test-aurora-0)
インスタンス作成中: aurora-size-test-aurora-3 (参照元: aurora-size-test-aurora-0)
インスタンス作成コマンドが正常に実行されました
```

##### 確認項目
- [ ] 各インスタンスの作成コマンドが正常に実行されたこと

#### 3.3: インスタンスの作成完了待機

新しいインスタンスが利用可能になるまで待機し、作成結果を確認します。

##### 実行コマンド

```bash
START_TIME=$(date +%s)

echo "新しいインスタンスが利用可能になるのを待機中..."
for INSTANCE_ID in $(echo "$ADDITIONAL_INSTANCES" | tr ' ' '\n'); do
  aws-vault exec mizzy -- aws rds wait db-instance-available --db-instance-identifier "${INSTANCE_ID}" &
done
wait

echo "追加インスタンスの作成が完了しました"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
新しいインスタンスが利用可能になるのを待機中...
追加インスタンスの作成が完了しました
実行時間: 300秒
```

##### 確認項目
- [ ] エラーなく完了メッセージが表示されること

### ステップ4: 旧インスタンスと新インスタンスの入れ替え

このステップでは、旧インスタンスを削除し、新インスタンスをリネームして、フェイルオーバーを実行することで、クラスターを新しいインスタンスに完全に切り替えます。

> [!NOTE]
> この手順は2インスタンス構成での例です。1インスタンスのdev環境では、コンソール上で以下の作業を行ってください：
> - 旧インスタンスを削除
> - 新インスタンスを旧インスタンスの名前にリネーム

**全体の流れ:**
1. 古いReaderを削除 → 新インスタンスをリネーム（4.1, 4.2）
2. 新しいインスタンス（Reader）へフェイルオーバー実行（4.3）※ダウンタイム30秒〜1分
3. 古いWriter（現Reader）を削除 → 新インスタンスをリネーム（4.4, 4.5）
4. （オプション）Writer/Readerの役割を元に戻す（4.6）※ダウンタイム30秒〜1分

#### 4.1: 古いReaderインスタンスを削除

古いReaderインスタンスを削除します。

##### 実行コマンド

```bash
OLD_INSTANCE_TO_DELETE="$ORIGINAL_READER"

OLD_INSTANCE_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$OLD_INSTANCE_TO_DELETE" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

echo ""
echo "=== 実行内容の確認 ==="
echo "削除対象: $OLD_INSTANCE_TO_DELETE (古いReader、$OLD_INSTANCE_CLASS)"
echo ""
echo -n "上記の操作を実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo ""
echo "古いインスタンスを削除中: $OLD_INSTANCE_TO_DELETE"
aws-vault exec mizzy -- aws rds delete-db-instance \
  --db-instance-identifier $OLD_INSTANCE_TO_DELETE \
  --skip-final-snapshot \
  --no-delete-automated-backups > /dev/null

echo "削除完了を待機中..."
aws-vault exec mizzy -- aws rds wait db-instance-deleted --db-instance-identifier $OLD_INSTANCE_TO_DELETE

echo "削除が完了しました"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== 実行内容の確認 ===
削除対象: aurora-size-test-aurora-1 (古いReader、db.t4g.medium)

上記の操作を実行しますか？ (yes/no): yes

古いインスタンスを削除中: aurora-size-test-aurora-1
削除完了を待機中...
削除が完了しました
実行時間: 500秒
```

##### 確認項目
- [ ] エラーなく削除が完了したこと

#### 4.2: 新しいインスタンスをリネーム

削除が完了した後、新しいインスタンスを削除したインスタンスの名前にリネームします。

##### 実行コマンド

```bash
READER_NUMBER=$(echo "$ORIGINAL_READER" | grep -oE '[0-9]+$')
NEW_INSTANCE_TO_RENAME="${CLUSTER_ID}-$((READER_NUMBER + INSTANCE_COUNT))"
TARGET_NAME="$ORIGINAL_READER"

NEW_INSTANCE_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$NEW_INSTANCE_TO_RENAME" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

echo ""
echo "=== 実行内容の確認 ==="
echo "リネーム: $NEW_INSTANCE_TO_RENAME ($NEW_INSTANCE_CLASS) → $TARGET_NAME"
echo ""
echo -n "上記の操作を実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo ""
echo "${NEW_INSTANCE_TO_RENAME}を${TARGET_NAME}にリネーム中..."
aws-vault exec mizzy -- aws rds modify-db-instance \
  --db-instance-identifier $NEW_INSTANCE_TO_RENAME \
  --new-db-instance-identifier $TARGET_NAME \
  --apply-immediately > /dev/null

echo "リネーム処理を待機中..."
sleep 30

echo "リネーム完了を確認中..."
while true; do
  if aws-vault exec mizzy -- aws rds describe-db-instances \
    --db-instance-identifier $TARGET_NAME > /dev/null 2>&1; then
    echo "リネームが完了しました"
    break
  fi
  echo -n "."
  sleep 5
done

echo "インスタンスの再起動を待機中..."
sleep 10

echo "インスタンスが利用可能になるまで待機中..."
aws-vault exec mizzy -- aws rds wait db-instance-available --db-instance-identifier $TARGET_NAME
echo "インスタンスが利用可能になりました"

echo ""
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== 実行内容の確認 ===
リネーム: aurora-size-test-aurora-3 (db.r7g.large) → aurora-size-test-aurora-1

上記の操作を実行しますか？ (yes/no): yes

aurora-size-test-aurora-3をaurora-size-test-aurora-1にリネーム中...
リネーム処理を待機中...
リネーム完了を確認中...
リネームが完了しました
インスタンスの再起動を待機中...
インスタンスが利用可能になるまで待機中...
インスタンスが利用可能になりました

実行時間: 320秒
```

##### 確認項目
- [ ] エラーなくリネームが完了したこと

#### 4.3: フェイルオーバー実行

新しいインスタンスへフェイルオーバーを実行します。

> [!CAUTION]
> この操作により30秒〜1分のダウンタイムが発生します。

##### 実行コマンド

```bash
TARGET_WRITER="$ORIGINAL_READER"

CURRENT_WRITER_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$ORIGINAL_WRITER" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

TARGET_WRITER_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$TARGET_WRITER" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

echo ""
echo "=== フェイルオーバーの確認 ==="
echo "現在のWriter: $ORIGINAL_WRITER ($CURRENT_WRITER_CLASS)"
echo "新しいWriter: $TARGET_WRITER ($TARGET_WRITER_CLASS)"
echo ""
echo -n "フェイルオーバーを実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo "フェイルオーバーを開始中..."
aws-vault exec mizzy -- aws rds failover-db-cluster \
  --db-cluster-identifier $CLUSTER_ID \
  --target-db-instance-identifier $TARGET_WRITER > /dev/null

echo "フェイルオーバーの完了を待機中..."
while true; do
  NEW_WRITER=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text)

  if [ "$NEW_WRITER" = "$TARGET_WRITER" ]; then
    echo "フェイルオーバーが正常に完了しました！"
    break
  fi

  echo -n "."
  sleep 5
done

echo ""

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== フェイルオーバーの確認 ===
現在のWriter: aurora-size-test-aurora-0 (db.t4g.medium)
新しいWriter: aurora-size-test-aurora-1 (db.r7g.large)

フェイルオーバーを実行しますか？ (yes/no): yes

フェイルオーバーを開始中...
フェイルオーバーの完了を待機中...
..........
フェイルオーバーが正常に完了しました！

実行時間: 45秒
```

##### 確認項目
- [ ] フェイルオーバーが正常に完了したこと

#### 4.4: 古いWriterインスタンスを削除

フェイルオーバー後、古いWriter（現在はReader）を削除します。

##### 実行コマンド

```bash
OLD_INSTANCE_TO_DELETE="$ORIGINAL_WRITER"

OLD_INSTANCE_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$OLD_INSTANCE_TO_DELETE" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

echo ""
echo "=== 実行内容の確認 ==="
echo "削除対象: $OLD_INSTANCE_TO_DELETE (古いWriter、現在Reader、$OLD_INSTANCE_CLASS)"
echo ""
echo -n "上記の操作を実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo ""
echo "古いインスタンスを削除中: $OLD_INSTANCE_TO_DELETE"
aws-vault exec mizzy -- aws rds delete-db-instance \
  --db-instance-identifier $OLD_INSTANCE_TO_DELETE \
  --skip-final-snapshot \
  --no-delete-automated-backups > /dev/null

echo "削除完了を待機中..."
aws-vault exec mizzy -- aws rds wait db-instance-deleted --db-instance-identifier $OLD_INSTANCE_TO_DELETE

echo "削除が完了しました"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== 実行内容の確認 ===
削除対象: aurora-size-test-aurora-0 (古いWriter、現在Reader、db.t4g.medium)

上記の操作を実行しますか？ (yes/no): yes

古いインスタンスを削除中: aurora-size-test-aurora-0
削除完了を待機中...
削除が完了しました
実行時間: 500秒
```

##### 確認項目
- [ ] エラーなく削除が完了したこと

#### 4.5: 新しいインスタンスをリネーム

削除が完了した後、新しいインスタンスを削除したインスタンスの名前にリネームします。

##### 実行コマンド

```bash
WRITER_NUMBER=$(echo "$ORIGINAL_WRITER" | grep -oE '[0-9]+$')
NEW_INSTANCE_TO_RENAME="${CLUSTER_ID}-$((WRITER_NUMBER + INSTANCE_COUNT))"
TARGET_NAME="$ORIGINAL_WRITER"

NEW_INSTANCE_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$NEW_INSTANCE_TO_RENAME" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

echo ""
echo "=== 実行内容の確認 ==="
echo "リネーム: $NEW_INSTANCE_TO_RENAME ($NEW_INSTANCE_CLASS) → $TARGET_NAME"
echo ""
echo -n "上記の操作を実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo ""
echo "${NEW_INSTANCE_TO_RENAME}を${TARGET_NAME}にリネーム中..."
aws-vault exec mizzy -- aws rds modify-db-instance \
  --db-instance-identifier $NEW_INSTANCE_TO_RENAME \
  --new-db-instance-identifier $TARGET_NAME \
  --apply-immediately > /dev/null

echo "リネーム処理を待機中..."
sleep 30

echo "リネーム完了を確認中..."
while true; do
  if aws-vault exec mizzy -- aws rds describe-db-instances \
    --db-instance-identifier $TARGET_NAME > /dev/null 2>&1; then
    echo "リネームが完了しました"
    break
  fi
  echo -n "."
  sleep 5
done

echo "インスタンスの再起動を待機中..."
sleep 10

echo "インスタンスが利用可能になるまで待機中..."
aws-vault exec mizzy -- aws rds wait db-instance-available --db-instance-identifier $TARGET_NAME
echo "インスタンスが利用可能になりました"

echo ""
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== 実行内容の確認 ===
リネーム: aurora-size-test-aurora-2 (db.r7g.large) → aurora-size-test-aurora-0

上記の操作を実行しますか？ (yes/no): yes

aurora-size-test-aurora-2をaurora-size-test-aurora-0にリネーム中...
リネーム処理を待機中...
リネーム完了を確認中...
リネームが完了しました
インスタンスの再起動を待機中...
インスタンスが利用可能になるまで待機中...
インスタンスが利用可能になりました

実行時間: 320秒
```

##### 確認項目
- [ ] エラーなくリネームが完了したこと

#### 4.6: （オプション）Writer/Readerの役割を元に戻す

元のインスタンス番号とWriter/Readerの関係を維持したい場合は、追加のフェイルオーバーを実行します。

> [!CAUTION]
> この操作により30秒〜1分のダウンタイムが発生します。

##### 実行コマンド

```bash
RETURN_TO_ORIGINAL_WRITER="$ORIGINAL_WRITER"

TARGET_WRITER_CLASS=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --db-instance-identifier "$RETURN_TO_ORIGINAL_WRITER" \
  --query 'DBInstances[0].DBInstanceClass' \
  --output text)

CURRENT_WRITER_NOW=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
  --output text)

echo ""
echo "=== Writer/Readerの役割を元に戻す ==="
echo "現在のWriter: $CURRENT_WRITER_NOW ($TARGET_WRITER_CLASS)"
echo "新しいWriter: $RETURN_TO_ORIGINAL_WRITER ($TARGET_WRITER_CLASS)"
echo ""
echo -n "フェイルオーバーを実行しますか？ (yes/no): "
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "操作をキャンセルしました"
  return
fi

START_TIME=$(date +%s)

echo ""
echo "フェイルオーバーを開始中..."
aws-vault exec mizzy -- aws rds failover-db-cluster \
  --db-cluster-identifier $CLUSTER_ID \
  --target-db-instance-identifier $RETURN_TO_ORIGINAL_WRITER > /dev/null

echo "フェイルオーバーの完了を待機中..."
while true; do
  NEW_WRITER=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' \
    --output text)

  if [ "$NEW_WRITER" = "$RETURN_TO_ORIGINAL_WRITER" ]; then
    echo "フェイルオーバーが正常に完了しました！"
    break
  fi

  echo -n "."
  sleep 5
done

echo ""

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
=== Writer/Readerの役割を元に戻す ===
現在のWriter: aurora-size-test-aurora-1 (db.r7g.large)
新しいWriter: aurora-size-test-aurora-0 (db.r7g.large)

フェイルオーバーを実行しますか？ (yes/no): yes

フェイルオーバーを開始中...
フェイルオーバーの完了を待機中...
フェイルオーバーが正常に完了しました！

実行時間: 45秒
```

##### 確認項目
- [ ] aurora-0がWriter、aurora-1がReaderになっていること


### ステップ5: 最終確認

全ての変更が正常に完了したことを確認します。

#### 実行コマンド
```bash
echo ""
echo "=== 最終的なクラスター構成 ==="
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier,IsClusterWriter]' \
  --output table

echo ""
echo "=== 最終的なインスタンスの詳細 ==="
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
  --output table
```

#### 期待される出力例
```
=== 最終的なクラスター構成 ===
----------------------------------------
|          DescribeDBClusters          |
+-----------------------------+--------+
|  aurora-size-test-aurora-1  |  False |
|  aurora-size-test-aurora-0  |  True  |
+-----------------------------+--------+

=== 最終的なインスタンスの詳細 ===
------------------------------------------------------------
|                    DescribeDBInstances                   |
+----------------------------+----------------+------------+
|  aurora-size-test-aurora-0 |  db.r7g.large  |  available |
|  aurora-size-test-aurora-1 |  db.r7g.large  |  available |
+----------------------------+----------------+------------+
```

#### 確認項目
**クラスター構成の確認（1つ目の表）:**
- [ ] インスタンスが元の台数に戻っていること
- [ ] Writer（True）とReader（False）の役割が正しく設定されていること

**インスタンス詳細の確認（2つ目の表）:**
- [ ] 全インスタンスが新しいインスタンスクラスになっていること
- [ ] 全インスタンスがavailable状態であること

### ステップ6: Terraformコードの更新

ステップ4で古いインスタンスの削除とリネームが完了し、Terraformが管理しているaurora-0とaurora-1のインスタンスクラスが変更されたため、コードを現状に合わせて更新します。

#### variables.tfの更新

instance_classのデフォルト値をTARGET_INSTANCE_CLASSに更新します。

##### 変更内容
```diff
# variables.tf
 variable "instance_class" {
   description = "Instance class for Aurora instances"
   type        = string
-  default     = "db.t4g.medium"
+  default     = "db.r7g.large"  # 新しいサイズに更新
 }
```

#### Terraform planで確認

Terraformの状態を確認し、インフラと一致することを確認します。

##### 実行コマンド
```bash
START_TIME=$(date +%s)

echo "Terraform設定を検証中..."
aws-vault exec mizzy -- terraform refresh
aws-vault exec mizzy -- terraform plan

echo ""
echo "現在の状態に合わせて設定が更新されました"
echo "最終構成:"
echo "  aurora-0: Reader (db.r7g.large)"
echo "  aurora-1: Writer (db.r7g.large)"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

##### 期待される出力例
```
Terraform設定を検証中...
No changes. Your infrastructure matches the configuration.

現在の状態に合わせて設定が更新されました
最終構成:
  aurora-0: Reader (db.r7g.large)
  aurora-1: Writer (db.r7g.large)
実行時間: 5秒
```

##### 確認項目
**Terraformコードの確認:**
- [ ] variables.tfのinstance_classがTARGET_INSTANCE_CLASSに更新されたこと

**Terraform実行結果の確認:**
- [ ] terraform planで「No changes」と表示されること
- [ ] Terraformステートが現在のインフラと一致していること

## メリット

1. **ダウンタイム最小化**: フェイルオーバー時の30秒〜1分のみ
2. **手順の簡素化**: インスタンス追加が1回で完了
3. **時間短縮**: 並列処理により全体の作業時間が短縮
4. **リスク低減**: すべての新しいインスタンスが準備完了してから切り替え

## 注意事項

1. **一時的なコスト増加**:
   - 最大4インスタンスが同時に稼働する期間がある（通常10-15分程度）
   - AWS RDSは秒単位課金なので、影響は限定的

2. **接続プールへの影響**:
   - 新しいリーダーインスタンスへの接続が自動的に分散されることを確認
   - アプリケーション側の接続プール設定の確認

3. **CloudWatch監視**:
   - レプリケーションラグの監視
   - CPU、メモリ使用率の確認

4. **事前準備**:
   - 最新のスナップショットが存在することを確認
   - アプリケーション側で再接続ロジックが実装されていることを確認

## トラブルシューティング

### インスタンス作成でエラーが出る場合

```bash
# クォータ確認
aws service-quotas get-service-quota \
  --service-code rds \
  --quota-code L-952B80B8 \
  --query 'Quota.Value'

# 利用可能なインスタンスタイプ確認
aws rds describe-orderable-db-instance-options \
  --engine aurora-postgresql \
  --engine-version 15.4 \
  --db-instance-class $TARGET_INSTANCE_CLASS \
  --query 'OrderableDBInstanceOptions[0].AvailabilityZones[*]'
```

### フェイルオーバーに時間がかかる場合

```bash
# クラスターイベントを確認
aws rds describe-events \
  --source-identifier $CLUSTER_ID \
  --source-type db-cluster \
  --duration 30 \
  --output table
```

### ロールバック手順

問題が発生した場合は、同じ手順で元のインスタンスサイズに戻します：

```bash
# 元のサイズに戻す場合も同じ手順
TARGET_INSTANCE_CLASS="db.t4g.medium"  # 元のサイズ
# 上記の手順を再度実行
```
