# Aurora PostgreSQL ブルーグリーンデプロイメント ロールバック手順書

## 重要な注意事項

> [!CAUTION]
> **想定ダウンタイム**: この手順によるロールバックでは、クラスター名とインスタンス名の変更により**約15-20分のダウンタイム**が発生します

> [!WARNING]
> **データ損失**: ロールバックを実行すると、スイッチオーバー後に新環境で行われたすべてのデータ変更が失われます

> [!NOTE]
> **前提条件**: 旧バージョンの環境（`-old1` サフィックス付きクラスター）が削除されている場合は、この手順によるロールバックはできません

## 概要
本手順書では、ブルーグリーンデプロイメント後に手動でクラスター名を変更することで、Aurora PostgreSQL クラスターをロールバックする手順を説明します。

### 手順の流れ
1. **現在の状態確認** - ブルーグリーンデプロイメント、クラスター、バージョンの状態確認
2. **ロールバック実行前の準備** - エンドポイント保存、データバックアップ用スナップショット作成
3. **ブルーグリーンデプロイメントの削除** - 名前変更の妨げとなるリソースを削除
4. **現在の環境の名前変更** - アップグレード後環境を`-to-delete`サフィックス付きに変更
5. **元バージョン環境の名前復元** - 旧環境の`-old1`サフィックスを削除して元の名前に戻す
6. **ロールバック後の確認** - バージョン、エンドポイント、インスタンスの確認
7. **不要環境の削除** - `-to-delete`サフィックス付き環境をクリーンアップ
8. **Terraformとの同期確認** - コードとインフラの一貫性を確保

> [!WARNING]
> AWS RDS ブルーグリーンデプロイメントには公式のスイッチバック機能がありません。そのため、ロールバックにはクラスター名の手動変更を行います。

## 前提条件
- ブルーグリーンデプロイメントのスイッチオーバーが完了している
- ブルーグリーンデプロイメントのリソースがまだ削除されていない
- 元のバージョンの環境（現在は `-old1` サフィックス付き）が存在している


---

## 手順

### 1. 現在の状態確認

#### 1.1 シェル変数の設定

ロールバック手順で使用するシェル変数を設定します。

##### 実行コマンド
```bash
CLUSTER_ID="aurora-bg-aurora-cluster"
AWS_REGION="ap-northeast-1"
```

##### 確認項目
- [ ] CLUSTER_IDとAWS_REGIONが正しく設定されている

#### 1.2 ブルーグリーンデプロイメントの存在確認

スイッチオーバーが完了したブルーグリーンデプロイメントが存在することを確認し、デプロイメントIDを取得します。

##### 実行コマンド
```bash
echo "[ブルーグリーンデプロイメントの確認]"
BG_DEPLOYMENT_ID=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --region $AWS_REGION \
  --query 'BlueGreenDeployments[?Status==`SWITCHOVER_COMPLETED`].BlueGreenDeploymentIdentifier' \
  --output text)

if [ -z "$BG_DEPLOYMENT_ID" ]; then
  echo "❌ エラー: スイッチオーバー完了済みのブルーグリーンデプロイメントが見つかりません"
  return 1
fi

BG_DEPLOYMENT_STATUS=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region $AWS_REGION \
  --query 'BlueGreenDeployments[0].Status' \
  --output text)

echo "✅ ブルーグリーンデプロイメントID: $BG_DEPLOYMENT_ID"
echo "✅ ステータス: $BG_DEPLOYMENT_STATUS"
```

##### 期待される出力
```
[ブルーグリーンデプロイメントの確認]
✅ ブルーグリーンデプロイメントID: bgd-xxxxxxxxxxxxxxx
✅ ステータス: SWITCHOVER_COMPLETED
```

##### 確認項目
- [ ] ブルーグリーンデプロイメントIDが表示されている
- [ ] ステータスが `SWITCHOVER_COMPLETED` である

#### 1.2 元バージョン環境の確認

ロールバック先となる元バージョンの環境が-old1サフィックス付きで存在し、利用可能であることを確認します。

##### 実行コマンド
```bash
OLD_CLUSTER_ID="${CLUSTER_ID}-old1"

echo "[元バージョン環境の確認]"
OLD_STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $OLD_CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].[Status]' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$OLD_STATUS" = "NOT_FOUND" ]; then
  echo "❌ エラー: 元バージョン環境のクラスター $OLD_CLUSTER_ID が見つかりません"
  return 1
fi

TARGET_VERSION=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $OLD_CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].EngineVersion' \
  --output text)

if [ "$OLD_STATUS" != "available" ]; then
  echo "❌ 元バージョン環境のクラスターが利用可能でありません: $OLD_STATUS"
  return 1
fi

echo "✅ クラスターID: $OLD_CLUSTER_ID"
echo "✅ ロールバック先バージョン: $TARGET_VERSION"
echo "✅ ステータス: $OLD_STATUS"
```

##### 期待される出力
```
[元バージョン環境の確認]
✅ クラスターID: aurora-bg-aurora-cluster-old1
✅ ロールバック先バージョン: XX.XX
✅ ステータス: available
```

##### 確認項目
- [ ] 元バージョン環境のクラスターが存在する（-old1サフィックス付き）
- [ ] ロールバック先バージョンが正しい
- [ ] ステータスが `available` である

#### 1.3 現在のクラスター情報を確認

現在の本番環境（アップグレード後）の状態とバージョンを確認します。

##### 実行コマンド
```bash
echo "[現在のクラスター確認]"
CURRENT_STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].[Status]' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CURRENT_STATUS" = "NOT_FOUND" ]; then
  echo "❌ エラー: クラスター $CLUSTER_ID が見つかりません"
  return 1
fi

CURRENT_VERSION=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].EngineVersion' \
  --output text)

if [ "$CURRENT_STATUS" != "available" ]; then
  echo "❌ クラスターステータスが利用可能でありません: $CURRENT_STATUS"
  return 1
fi

echo "✅ クラスターID: $CLUSTER_ID"
echo "✅ 現在のバージョン: $CURRENT_VERSION"
echo "✅ ステータス: $CURRENT_STATUS"
```

##### 期待される出力
```
[現在のクラスター確認]
✅ クラスターID: aurora-bg-aurora-cluster
✅ 現在のバージョン: XX.XX
✅ ステータス: available
```

##### 確認項目
- [ ] 現在のクラスターが存在する
- [ ] 現在のバージョンが正しい（アップグレード後のバージョン）
- [ ] ステータスが `available` である

#### 1.4 チェック結果のサマリー表示

すべての事前確認が完了し、ロールバック可能な状態であることを最終確認します。

##### 実行コマンド
```bash
echo "========================================="
echo "✅ すべてのチェックに合格しました"
echo ""
echo "設定されたシェル変数:"
echo "  - CLUSTER_ID: $CLUSTER_ID"
echo "  - AWS_REGION: $AWS_REGION"
echo "  - BG_DEPLOYMENT_ID: $BG_DEPLOYMENT_ID"
echo "  - CURRENT_VERSION: $CURRENT_VERSION"
echo "  - TARGET_VERSION: $TARGET_VERSION"
echo ""
echo "ロールバック情報:"
echo "  - ブルーグリーンデプロイメントID: $BG_DEPLOYMENT_ID"
echo "  - 現在のバージョン: $CURRENT_VERSION → ロールバック先: $TARGET_VERSION"
echo "  - 対象クラスター: ${CLUSTER_ID:-aurora-bg-aurora-cluster}"
echo "========================================="
```

##### 期待される出力
```
=========================================
✅ すべてのチェックに合格しました

設定されたシェル変数:
  - CLUSTER_ID: aurora-bg-aurora-cluster
  - AWS_REGION: ap-northeast-1
  - BG_DEPLOYMENT_ID: bgd-xxxxxxxxxxxxxxx
  - CURRENT_VERSION: XX.XX
  - TARGET_VERSION: YY.YY

ロールバック情報:
  - Blue/Green デプロイメントID: bgd-xxxxxxxxxxxxxxx
  - 現在のバージョン: XX.XX → ロールバック先: YY.YY
  - 対象クラスター: aurora-bg-aurora-cluster
=========================================
```

##### 確認項目
- [ ] すべてのシェル変数が正しく設定されている
- [ ] バージョンの変更方向が正しい（新→旧）

### 2. ロールバック実行前の準備

#### 2.1 エンドポイントの保存

ロールバック後の確認用に、現在のエンドポイントをシェル変数に保存します。

##### 実行コマンド
```bash
echo "[ロールバック前エンドポイントの保存]"
ORIGINAL_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].Endpoint' \
  --output text)

ORIGINAL_READER_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].ReaderEndpoint' \
  --output text)

echo "✅ ライターエンドポイント保存: $ORIGINAL_ENDPOINT"
echo "✅ リーダーエンドポイント保存: $ORIGINAL_READER_ENDPOINT"
```

##### 期待される出力
```
[ロールバック前エンドポイントの保存]
✅ ライターエンドポイント保存: aurora-bg-aurora-cluster.cluster-xxxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
✅ リーダーエンドポイント保存: aurora-bg-aurora-cluster.cluster-ro-xxxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
```

##### 確認項目
- [ ] ライターエンドポイントが正しい
- [ ] リーダーエンドポイントが正しい

#### 2.2 スナップショット作成

ロールバック実行前に、現在のデータを保存するためのスナップショットを作成します。

##### 実行コマンド
```bash
SNAPSHOT_ID="${CLUSTER_ID}-before-rollback-$(date +%Y%m%d-%H%M%S)"

echo "スナップショット作成中..."
echo "✅ スナップショットID: $SNAPSHOT_ID"
aws-vault exec mizzy -- aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier $SNAPSHOT_ID \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION >/dev/null

echo "✅ スナップショット作成を開始しました"
```

##### 期待される出力
```
スナップショット作成中...
✅ スナップショットID: aurora-bg-aurora-cluster-before-rollback-20240101-123456
✅ スナップショット作成を開始しました
```

##### 確認項目
- [ ] スナップショットIDが正しく表示されている
- [ ] スナップショット作成が開始された

#### 2.3 スナップショット作成完了の待機

スナップショット作成によりクラスターが一時的にbacking-up状態になるため、available状態に戻るまで待機します。

##### 実行コマンド
```bash

echo "クラスターが利用可能になるまで待機中..."
aws-vault exec mizzy -- aws rds wait db-cluster-available \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION

echo "✅ クラスターが利用可能になりました"
```

##### 期待される出力
```
クラスターが利用可能になるまで待機中...
✅ クラスターが利用可能になりました
```

##### 確認項目
- [ ] クラスターが利用可能状態に戻った

### 3. ブルーグリーンデプロイメントの削除

#### 3.1 ブルーグリーンデプロイメントの削除

クラスター名変更前に、ブルーグリーンデプロイメントを削除します。

##### 実行コマンド
```bash
if [ -z "$BG_DEPLOYMENT_ID" ]; then
  echo "エラー: BG_DEPLOYMENT_ID が設定されていません"
  return 1
fi

echo "[ブルーグリーンデプロイメントの削除]"
aws-vault exec mizzy -- aws rds delete-blue-green-deployment \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region $AWS_REGION >/dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "✅ ブルーグリーンデプロイメントを削除しました"
else
  aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
    --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
    --region $AWS_REGION >/dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    echo "ℹ️  ブルーグリーンデプロイメントは既に削除されています"
  else
    echo "⚠️  ブルーグリーンデプロイメントの削除に失敗しました"
  fi
fi
```

##### 期待される出力
```
[ブルーグリーンデプロイメントの削除]
✅ ブルーグリーンデプロイメントを削除しました
```

##### 確認項目
- [ ] ブルーグリーンデプロイメントが削除された

### 4. 現在の環境（アップグレード後環境）の名前変更

#### 4.1 現在のクラスター名を変更

現在の本番環境のクラスター名を-to-deleteサフィックス付きに変更します。

##### 実行コマンド
```bash
DELETE_TARGET_CLUSTER_ID="${CLUSTER_ID}-to-delete"

echo "[現在のクラスター名を変更]"
echo "✅ $CLUSTER_ID → $DELETE_TARGET_CLUSTER_ID に変更中"

aws-vault exec mizzy -- aws rds modify-db-cluster \
  --db-cluster-identifier $CLUSTER_ID \
  --new-db-cluster-identifier $DELETE_TARGET_CLUSTER_ID \
  --apply-immediately \
  --region $AWS_REGION >/dev/null

echo "✅ クラスター名の変更を開始しました"

echo "変更完了まで待機します..."
while true; do
  if aws-vault exec mizzy -- aws rds describe-db-clusters \
    --db-cluster-identifier $DELETE_TARGET_CLUSTER_ID \
    --region $AWS_REGION >/dev/null 2>&1; then
    
    STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
      --db-cluster-identifier $DELETE_TARGET_CLUSTER_ID \
      --region $AWS_REGION \
      --query 'DBClusters[0].Status' \
      --output text)
    
    if [ "$STATUS" = "available" ]; then
      echo "✅ クラスター名変更が完了しました"
      break
    else
      echo "待機中: $STATUS"
      sleep 10
    fi
  else
    echo "待機中: クラスター名変更処理中..."
    sleep 10
  fi
done
```

##### 期待される出力
```
[現在のクラスター名を変更]
✅ aurora-bg-aurora-cluster → aurora-bg-aurora-cluster-to-delete に変更中
✅ クラスター名の変更を開始しました
クラスター名変更の完了を待機中...
✅ クラスター名変更が完了しました
```

##### 確認項目
- [ ] クラスター名変更が完了した

#### 4.2 現在のインスタンス名を変更

現在の本番環境のインスタンス名を-to-deleteサフィックス付きに変更します。

##### 実行コマンド
```bash
DELETE_TARGET_CLUSTER_ID="${CLUSTER_ID}-to-delete"

echo "[現在のインスタンス名を変更]"
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$DELETE_TARGET_CLUSTER_ID" \
  --region $AWS_REGION \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  
  delete_target_instance_id="${instance_id}-to-delete"
  echo "✅ $instance_id → $delete_target_instance_id に変更中"
  
  aws-vault exec mizzy -- aws rds modify-db-instance \
    --db-instance-identifier "$instance_id" \
    --new-db-instance-identifier "$delete_target_instance_id" \
    --apply-immediately \
    --region $AWS_REGION >/dev/null
done

sleep 5

echo "インスタンス名変更の完了を待機中..."
while true; do
  ALL_DATA=$(aws-vault exec mizzy -- aws rds describe-db-instances \
    --filters "Name=db-cluster-id,Values=$DELETE_TARGET_CLUSTER_ID" \
    --region $AWS_REGION \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `to-delete`)].[DBInstanceIdentifier, DBInstanceStatus]' \
    --output text 2>/dev/null)
  
  if [ -z "$ALL_DATA" ]; then
    echo "待機中: インスタンス名変更処理中..."
    sleep 10
    continue
  fi
  
  ALL_AVAILABLE=false
  echo "$ALL_DATA" | while read instance_id instance_status; do
    if [ "$instance_status" != "available" ]; then
      echo "待機中: $instance_id は $instance_status"
    fi
  done | grep -q "待機中" || ALL_AVAILABLE=true
  
  if [ "$ALL_AVAILABLE" = "true" ]; then
    echo "✅ すべてのインスタンス名変更が完了しました"
    break
  fi
  
  sleep 10
done
```

##### 期待される出力
```
[現在のインスタンス名を変更]
✅ aurora-bg-aurora-instance-1 → aurora-bg-aurora-instance-1-to-delete に変更中
✅ aurora-bg-aurora-instance-2 → aurora-bg-aurora-instance-2-to-delete に変更中
インスタンス名変更の完了を待機中...
✅ すべてのインスタンス名変更が完了しました
```

##### 確認項目
- [ ] すべてのインスタンス名変更が完了した

### 5. 元バージョン環境の名前復元

#### 5.1 元バージョン環境のクラスター名を復元

元バージョン環境のクラスター名から-old1サフィックスを削除し、元の名前に戻します。

##### 実行コマンド
```bash
OLD_CLUSTER_ID="${CLUSTER_ID}-old1"

echo "[元バージョン環境のクラスター名を復元]"
echo "✅ $OLD_CLUSTER_ID → $CLUSTER_ID に復元中"

aws-vault exec mizzy -- aws rds modify-db-cluster \
  --db-cluster-identifier $OLD_CLUSTER_ID \
  --new-db-cluster-identifier $CLUSTER_ID \
  --apply-immediately \
  --region $AWS_REGION >/dev/null

echo "✅ クラスター名の変更を開始しました"

echo "変更完了まで待機します..."
while true; do
  if aws-vault exec mizzy -- aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_ID \
    --region $AWS_REGION >/dev/null 2>&1; then
    
    STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
      --db-cluster-identifier $CLUSTER_ID \
      --region $AWS_REGION \
      --query 'DBClusters[0].Status' \
      --output text)
    
    if [ "$STATUS" = "available" ]; then
      echo "✅ クラスター名復元が完了しました"
      break
    else
      echo "待機中: $STATUS"
      sleep 10
    fi
  else
    echo "待機中: クラスター名変更処理中..."
    sleep 10
  fi
done
```

##### 期待される出力
```
[元バージョン環境のクラスター名を復元]
✅ aurora-bg-aurora-cluster-old1 → aurora-bg-aurora-cluster に復元中
✅ クラスター名の変更を開始しました
クラスター名変更の完了を待機中...
✅ クラスター名復元が完了しました
```

##### 確認項目
- [ ] クラスター名復元が完了した

#### 5.2 元バージョン環境のインスタンス名を復元

元バージョン環境のインスタンス名から-old1サフィックスを削除し、元の名前に戻します。

##### 実行コマンド
```bash
echo "[元バージョン環境のインスタンス名を復元]"
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
  --region $AWS_REGION \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  
  if [[ "$instance_id" == *"-old1" ]]; then
    restored_instance_id="${instance_id%-old1}"
    echo "✅ $instance_id → $restored_instance_id に復元中"
    
    aws-vault exec mizzy -- aws rds modify-db-instance \
      --db-instance-identifier "$instance_id" \
      --new-db-instance-identifier "$restored_instance_id" \
      --apply-immediately \
      --region $AWS_REGION >/dev/null
  fi
done

sleep 5

echo "インスタンス名復元の完了を待機中..."
while true; do
  ALL_DATA=$(aws-vault exec mizzy -- aws rds describe-db-instances \
    --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
    --region $AWS_REGION \
    --query 'DBInstances[*].[DBInstanceIdentifier, DBInstanceStatus]' \
    --output text 2>/dev/null)
  
  if [ -z "$ALL_DATA" ]; then
    echo "待機中: インスタンス名復元処理中..."
    sleep 10
    continue
  fi
  
  HAS_OLD1=false
  ALL_NON_OLD1_AVAILABLE=false
  
  echo "$ALL_DATA" | grep -q "\-old1" && HAS_OLD1=true
  
  WAITING_OUTPUT=$(echo "$ALL_DATA" | while read instance_id instance_status; do
    if [[ "$instance_id" != *"-old1" ]]; then
      if [ "$instance_status" != "available" ]; then
        echo "待機中: $instance_id は $instance_status"
      fi
    fi
  done)
  
  if [ -n "$WAITING_OUTPUT" ]; then
    echo "$WAITING_OUTPUT"
  else
    ALL_NON_OLD1_AVAILABLE=true
  fi
  
  if [ "$HAS_OLD1" = "false" ] && [ "$ALL_NON_OLD1_AVAILABLE" = "true" ]; then
    echo "✅ すべてのインスタンス名復元が完了しました"
    break
  fi
  
  sleep 10
done
```

##### 期待される出力
```
[元バージョン環境のインスタンス名を復元]
✅ aurora-bg-aurora-instance-1-old1 → aurora-bg-aurora-instance-1 に復元中
✅ aurora-bg-aurora-instance-2-old1 → aurora-bg-aurora-instance-2 に復元中
インスタンス名復元の完了を待機中...
✅ すべてのインスタンス名復元が完了しました
```

##### 確認項目
- [ ] すべてのインスタンス名復元が完了した

### 6. ロールバック後の確認

#### 6.1 クラスターバージョンの確認

ロールバックが正常に完了し、バージョンが元のバージョンに戻っていることを確認します。

##### 実行コマンド
```bash
echo "[クラスターバージョンの確認]"
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].[DBClusterIdentifier,EngineVersion,Status]' \
  --output table

ACTUAL_VERSION=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].EngineVersion' \
  --output text)

CLUSTER_STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].Status' \
  --output text)

if [ "$ACTUAL_VERSION" != "$TARGET_VERSION" ]; then
  echo "❌ バージョン不一致: $ACTUAL_VERSION (期待値: $TARGET_VERSION)"
  return 1
fi

if [ "$CLUSTER_STATUS" != "available" ]; then
  echo "⚠️  クラスターステータス: $CLUSTER_STATUS"
fi

echo "✅ クラスター名: $CLUSTER_ID"
echo "✅ クラスターバージョン: $ACTUAL_VERSION"
echo "✅ クラスターステータス: $CLUSTER_STATUS"
```

##### 期待される出力
```
[クラスターバージョンの確認]
✅ クラスター名: aurora-bg-aurora-cluster
✅ バージョン: YY.YY
✅ ステータス: available
```

##### 確認項目
- [ ] クラスター名が正しい
- [ ] バージョンがロールバック先バージョンに戻っている
- [ ] クラスターステータスが `available` である

#### 6.2 インスタンスバージョンの確認

すべてのインスタンスが元のバージョンに戻っていることを確認します。

##### 実行コマンド
```bash
echo "[インスタンスバージョンの確認]"
INSTANCE_ERRORS=0

aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$CLUSTER_ID" \
  --region $AWS_REGION \
  --query 'DBInstances[*].[DBInstanceIdentifier,EngineVersion,DBInstanceStatus]' \
  --output text | while read INSTANCE_ID INSTANCE_VERSION INSTANCE_STATUS; do
  
  if [ "$INSTANCE_VERSION" = "$TARGET_VERSION" ] && [ "$INSTANCE_STATUS" = "available" ]; then
    echo "✅ $INSTANCE_ID: バージョン $INSTANCE_VERSION, ステータス $INSTANCE_STATUS"
  else
    echo "❌ $INSTANCE_ID: バージョン $INSTANCE_VERSION (期待値: $TARGET_VERSION), ステータス $INSTANCE_STATUS"
    INSTANCE_ERRORS=$((INSTANCE_ERRORS + 1))
  fi
done

if [ $INSTANCE_ERRORS -gt 0 ]; then
  echo "❌ $INSTANCE_ERRORS 個のインスタンスに問題があります"
  return 1
fi

echo "✅ すべてのインスタンスが正常です"
```

##### 期待される出力
```
[インスタンスバージョンの確認]
✅ aurora-bg-aurora-instance-1: バージョン YY.YY, ステータス available
✅ aurora-bg-aurora-instance-2: バージョン YY.YY, ステータス available
✅ すべてのインスタンスが正常です
```

##### 確認項目
- [ ] すべてのインスタンス名が元の名前になっている
- [ ] すべてのインスタンスがロールバック先バージョンに戻っている
- [ ] すべてのインスタンスステータスが `available` である

#### 6.3 エンドポイントの確認と比較

ロールバック後のエンドポイントがロールバック前と同じであることを確認します。

##### 実行コマンド
```bash
echo "[エンドポイントの確認と比較]"
CURRENT_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].Endpoint' \
  --output text)

CURRENT_READER_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].ReaderEndpoint' \
  --output text)

if [ -z "$ORIGINAL_ENDPOINT" ] || [ -z "$ORIGINAL_READER_ENDPOINT" ]; then
  echo "⚠️  エラー: ロールバック前のエンドポイントが保存されていません"
  return 1
fi

if [ "$CURRENT_ENDPOINT" = "$ORIGINAL_ENDPOINT" ]; then
  echo "✅ ライターエンドポイント変更なし: $CURRENT_ENDPOINT"
else
  echo "❌ ライターエンドポイント変更あり: $ORIGINAL_ENDPOINT → $CURRENT_ENDPOINT"
  return 1
fi

if [ "$CURRENT_READER_ENDPOINT" = "$ORIGINAL_READER_ENDPOINT" ]; then
  echo "✅ リーダーエンドポイント変更なし: $CURRENT_READER_ENDPOINT"
else
  echo "❌ リーダーエンドポイント変更あり: $ORIGINAL_READER_ENDPOINT → $CURRENT_READER_ENDPOINT"
  return 1
fi

echo "✅ すべてのエンドポイントがロールバック前と同じです"
```

##### 期待される出力
```
[エンドポイントの確認と比較]
✅ ライターエンドポイント変更なし: aurora-bg-aurora-cluster.cluster-xxxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
✅ リーダーエンドポイント変更なし: aurora-bg-aurora-cluster.cluster-ro-xxxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
✅ すべてのエンドポイントがロールバック前と同じです
```

##### 確認項目
- [ ] ライターエンドポイント変更なし
- [ ] リーダーエンドポイント変更なし

#### 6.4 検証結果のサマリー

ロールバック後のすべての検証が完了したことを最終確認します。

##### 実行コマンド
```bash
FINAL_STATUS=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].Status' \
  --output text)

echo "========================================="
echo "✅ ロールバック後の検証が完了しました"
echo ""
echo "現在の環境:"
echo "  - クラスター: $CLUSTER_ID"
echo "  - バージョン: $TARGET_VERSION"
echo "  - ステータス: $FINAL_STATUS"
echo "========================================="
```

##### 期待される出力
```
=========================================
✅ ロールバック後の検証が完了しました

現在の環境:
  - クラスター: aurora-bg-aurora-cluster
  - バージョン: 15.6
  - ステータス: available
=========================================
```

##### 確認項目
- [ ] クラスター名が正しい
- [ ] バージョンがロールバック先バージョンである
- [ ] ステータスが `available` である

### 7. ロールバック後不要になった環境の削除

#### 7.1 ロールバック後の不要環境のインスタンス一覧を取得

-to-deleteサフィックス付きのクラスターに属するインスタンスを特定します。

##### 実行コマンド
```bash
DELETE_TARGET_CLUSTER_ID="${CLUSTER_ID}-to-delete"

echo "[不要環境のインスタンス確認]"
DELETE_TARGET_INSTANCES=$(aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$DELETE_TARGET_CLUSTER_ID" \
  --region $AWS_REGION \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text 2>/dev/null || echo "")

if [ -z "$DELETE_TARGET_INSTANCES" ]; then
  echo "ℹ️  削除するインスタンスがありません"
  return 0
fi

echo "✅ 削除対象インスタンス:"
echo "$DELETE_TARGET_INSTANCES" | tr '\t' '\n' | while read instance; do
  echo "  - $instance"
done
```

##### 期待される出力
```
[不要環境のインスタンス確認]
✅ 削除対象インスタンス:
  - aurora-bg-aurora-instance-1-to-delete
  - aurora-bg-aurora-instance-2-to-delete
```

##### 確認項目
- [ ] 削除対象インスタンスが正しい

#### 7.2 不要環境のインスタンスを削除

不要になったアップグレード後の環境のインスタンスをすべて削除します。

##### 実行コマンド
```bash
if [ -z "$DELETE_TARGET_INSTANCES" ]; then
  echo "削除対象インスタンスがありません"
  return 0
fi

echo "[不要環境インスタンスの削除]"
echo "$DELETE_TARGET_INSTANCES" | tr '\t' ' ' | xargs -n1 | while read INSTANCE_ID; do
  if [ -n "$INSTANCE_ID" ]; then
    echo "削除中: $INSTANCE_ID"
    aws-vault exec mizzy -- aws rds delete-db-instance \
      --db-instance-identifier "$INSTANCE_ID" \
      --skip-final-snapshot \
      --region $AWS_REGION >/dev/null 2>&1
  fi
done
```

##### 期待される出力
```
[不要環境インスタンスの削除]
削除中: aurora-bg-aurora-cluster-to-delete-instance-1
削除中: aurora-bg-aurora-cluster-to-delete-instance-2
```

##### 確認項目
- [ ] すべての不要インスタンスの削除が開始された

#### 7.3 インスタンス削除の完了待機

すべてのインスタンスの削除が完了するまで待機します。

##### 実行コマンド
```bash
if [ -z "$DELETE_TARGET_INSTANCES" ]; then
  return 0
fi

echo "[インスタンス削除の完了待機]"
echo "$DELETE_TARGET_INSTANCES" | tr '\t' ' ' | xargs -n1 | while read INSTANCE_ID; do
  if [ -n "$INSTANCE_ID" ]; then
    echo "待機中: $INSTANCE_ID の削除"
    aws-vault exec mizzy -- aws rds wait db-instance-deleted \
      --db-instance-identifier "$INSTANCE_ID" \
      --region $AWS_REGION 2>/dev/null || true
  fi
done

echo "✅ インスタンスの削除が完了しました"
```

##### 期待される出力
```
[インスタンス削除の完了待機]
待機中: aurora-bg-aurora-cluster-to-delete-instance-1 の削除
待機中: aurora-bg-aurora-cluster-to-delete-instance-2 の削除
✅ インスタンスの削除が完了しました
```

##### 確認項目
- [ ] すべてのインスタンスの削除が完了した

#### 7.4 不要環境のクラスターを削除

インスタンス削除後、-to-deleteサフィックス付きのクラスター本体を削除します。

##### 実行コマンド
```bash
DELETE_TARGET_CLUSTER_ID="${CLUSTER_ID}-to-delete"

echo "[不要環境クラスターの削除]"
aws-vault exec mizzy -- aws rds delete-db-cluster \
  --db-cluster-identifier $DELETE_TARGET_CLUSTER_ID \
  --skip-final-snapshot \
  --region $AWS_REGION >/dev/null 2>&1 && \
  echo "削除中: $DELETE_TARGET_CLUSTER_ID" || \
  echo "ℹ️  クラスターは既に削除されています"
```

##### 期待される出力
```
[不要環境クラスターの削除]
削除中: aurora-bg-aurora-cluster-to-delete
```

##### 確認項目
- [ ] 不要環境クラスターの削除が開始された

#### 7.5 クラスター削除の完了待機

クラスターの削除が完了し、すべてのクリーンアップが終了したことを確認します。

##### 実行コマンド
```bash
DELETE_TARGET_CLUSTER_ID="${CLUSTER_ID}-to-delete"

echo "[クラスター削除の完了待機]"
aws-vault exec mizzy -- aws rds wait db-cluster-deleted \
  --db-cluster-identifier $DELETE_TARGET_CLUSTER_ID \
  --region $AWS_REGION 2>/dev/null && \
  echo "✅ クラスターの削除が完了しました" || \
  echo "ℹ️  クラスターは既に削除されています"
```

##### 期待される出力
```
[クラスター削除の完了待機]
✅ クラスターの削除が完了しました
```

##### 確認項目
- [ ] 不要環境クラスターの削除が完了した

### 8. Terraformコードとの同期確認

#### 8.1 実際のバージョンを取得

現在のAuroraクラスターの実際のバージョンを取得します。

##### 実行コマンド
```bash
ACTUAL_VERSION=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $AWS_REGION \
  --query 'DBClusters[0].EngineVersion' \
  --output text)

echo "実際のクラスターバージョン: $ACTUAL_VERSION"
```

##### 期待される出力
```
実際のクラスターバージョン: YY.YY
```

##### 確認項目
- [ ] ロールバック後のバージョンが表示される

#### 8.2 terraform.tfvars のバージョンを確認

Terraformの設定ファイルが実際の環境と一致しているか確認します。

##### 実行コマンド
```bash
if [ ! -f terraform.tfvars ]; then
  echo "⚠️  terraform.tfvars が見つかりません"
  return 1
fi

TFVARS_VERSION=$(grep "aurora_engine_version" terraform.tfvars | sed 's/.*"\(.*\)".*/\1/')
echo "terraform.tfvars のバージョン: $TFVARS_VERSION"

if [ "$ACTUAL_VERSION" = "$TFVARS_VERSION" ]; then
  echo "✅ Terraformの設定は実際の環境と一致しています"
else
  echo "⚠️  バージョンが一致しません"
  echo "以下の内容でterraform.tfvarsを更新してください:"
  echo "aurora_engine_version = \"$ACTUAL_VERSION\""
fi
```

##### 期待される出力（一致している場合）
```
terraform.tfvars のバージョン: YY.YY
✅ Terraformの設定は実際の環境と一致しています
```

##### 期待される出力（不一致の場合）
```
terraform.tfvars のバージョン: XX.XX
⚠️  バージョンが一致しません
以下の内容でterraform.tfvarsを更新してください:
aurora_engine_version = "YY.YY"
```

##### 確認項目
- [ ] terraform.tfvars ファイルが存在する
- [ ] バージョンが一致しているか確認
- [ ] 不一致の場合は更新方法が表示される

#### 8.3 モジュールのデフォルト値を確認

Terraformモジュールのデフォルト値も必要に応じて更新します。

##### 実行コマンド
```bash
if [ ! -f modules/aurora/variables.tf ]; then
  return 0
fi

MODULE_DEFAULT=$(grep -A2 'variable "engine_version"' modules/aurora/variables.tf | grep default | sed 's/.*"\(.*\)".*/\1/')

if [ ! -z "$MODULE_DEFAULT" ]; then
  echo "モジュールのデフォルトバージョン: $MODULE_DEFAULT"
  if [ "$MODULE_DEFAULT" != "$ACTUAL_VERSION" ]; then
    echo "ℹ️  モジュールのデフォルト値も更新することを推奨します"
  fi
fi
```

##### 期待される出力
```
モジュールのデフォルトバージョン: 15.6
```

##### 確認項目
- [ ] モジュールのデフォルトバージョンが表示される


## 参考情報

- [AWS Documentation: ブルーグリーンデプロイメント](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/blue-green-deployments.html)
- [AWS CLI Reference: modify-db-cluster](https://docs.aws.amazon.com/cli/latest/reference/rds/modify-db-cluster.html)
- [AWS CLI Reference: delete-blue-green-deployment](https://docs.aws.amazon.com/cli/latest/reference/rds/delete-blue-green-deployment.html)