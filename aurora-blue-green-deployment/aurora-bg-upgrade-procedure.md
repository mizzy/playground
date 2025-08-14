# Aurora PostgreSQL ブルー/グリーン デプロイメントによるバージョンアップ手順書

## 概要
本手順書では、Aurora PostgreSQL クラスターを 15.6 から 15.10 へ、ブルー/グリーン デプロイメントを使用して安全にアップグレードする手順を説明します。

## 前提条件
- AWS CLI がインストールされていること
- 適切な AWS 認証情報が設定されていること (`aws-vault exec mizzy --` を使用)
- 現在の Aurora PostgreSQL バージョン: 15.6
- ターゲットバージョン: 15.10

## 現在の環境情報
- **クラスター識別子**: aurora-bg-aurora-cluster
- **インスタンス識別子プレフィックス**: aurora-bg-aurora-instance-
- **リージョン**: ap-northeast-1

---

## 手順

### 1. 事前確認

#### 1.1 現在のクラスター情報を確認
```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].[DBClusterIdentifier,EngineVersion,Status]' \
  --output table
```

#### 1.2 現在のインスタンス情報を確認
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,EngineVersion,DBInstanceStatus]' \
  --output table
```

#### 1.3 ターゲットバージョン（15.10）が利用可能であることを確認
```bash
aws-vault exec mizzy -- aws rds describe-db-engine-versions \
  --engine aurora-postgresql \
  --engine-version 15.10 \
  --region ap-northeast-1 \
  --query 'DBEngineVersions[0].[Engine,EngineVersion,DBParameterGroupFamily]' \
  --output table
```

バージョンが表示されれば、15.10へのアップグレードが可能です。

### 2. 論理レプリケーションの有効化（必要な場合）

Terraformで`rds.logical_replication = 1`を設定した後、インスタンスの再起動をしていない場合、設定を反映させるために再起動が必要です。

#### 2.1 インスタンスを再起動して適用
クラスター内の全インスタンスを個別に再起動：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  aws-vault exec mizzy -- aws rds reboot-db-instance \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1 >/dev/null
  echo "$instance_id を再起動中..."
done
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1 を再起動中...
aurora-bg-aurora-instance-2 を再起動中...
```

再起動完了まで待機：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  echo "$instance_id の再起動完了を待機中..."
  aws-vault exec mizzy -- aws rds wait db-instance-available \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1
  echo "$instance_id の再起動が完了しました"
done

echo "全インスタンスの再起動が完了しました"
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1 の再起動が完了しました
aurora-bg-aurora-instance-2 の再起動が完了しました
全インスタンスの再起動が完了しました
```

### 3. ブルー/グリーン デプロイメントの作成

#### 3.1 クラスターのARNを取得
```bash
CLUSTER_ARN=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].DBClusterArn' \
  --output text)
```

```bash
echo $CLUSTER_ARN
```

#### 3.2 ブルー/グリーン デプロイメントを作成
```bash
BG_DEPLOYMENT_ID=$(aws-vault exec mizzy -- aws rds create-blue-green-deployment \
  --blue-green-deployment-name aurora-bg-upgrade-15-10 \
  --source $CLUSTER_ARN \
  --target-engine-version 15.10 \
  --target-db-cluster-parameter-group-name aurora-bg-aurora-pg15-cluster-params \
  --target-db-parameter-group-name aurora-bg-aurora-pg15-params \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployment.BlueGreenDeploymentIdentifier' \
  --output text)
```

```bash
echo $BG_DEPLOYMENT_ID
```

#### 3.3 デプロイメントのステータスを確認
```bash
aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[0].[BlueGreenDeploymentIdentifier,Status,StatusDetails]' \
  --output table
```

**期待される出力例**:
```
-----------------------------------------------
|       DescribeBlueGreenDeployments         |
+---------------------------------------------+
|  bgd-xxxxxxxxxxxxxxx                       |
|  PROVISIONING                               |
|  None                                       |
+---------------------------------------------+
```

`PROVISIONING`はグリーン環境を作成中の状態です。

#### 3.4 デプロイメントが利用可能になるまで待機
**注意**: グリーン環境の作成には時間がかかります（データベースのサイズやインスタンス数により30分〜1時間以上）。

```bash
while true; do
  STATUS=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
    --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
    --region ap-northeast-1 \
    --query 'BlueGreenDeployments[0].Status' \
    --output text)
  
  echo "$(date): ステータス = $STATUS"
  
  if [ "$STATUS" = "AVAILABLE" ]; then
    echo "ブルー/グリーン デプロイメントが利用可能になりました"
    break
  elif [ "$STATUS" = "PROVISIONING_FAILED" ] || [ "$STATUS" = "INVALID_CONFIGURATION" ]; then
    echo "ブルー/グリーン デプロイメントの作成に失敗しました"
    exit 1
  fi
  
  sleep 30
done
```

**期待される出力例**:
```
Wed Jan 15 10:30:00 JST 2025: ステータス = PROVISIONING
Wed Jan 15 10:30:30 JST 2025: ステータス = PROVISIONING
Wed Jan 15 10:31:00 JST 2025: ステータス = PROVISIONING
...（15〜60分程度続く）...
Wed Jan 15 10:45:00 JST 2025: ステータス = AVAILABLE
ブルー/グリーン デプロイメントが利用可能になりました
```

### 4. グリーン環境の再起動

#### 4.1 グリーン環境のクラスター識別子を取得
```bash
GREEN_CLUSTER_ARN=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[0].Target' \
  --output text)

GREEN_CLUSTER_ID=$(echo $GREEN_CLUSTER_ARN | awk -F: '{print $NF}')
```

```bash
echo $GREEN_CLUSTER_ID
```

#### 4.2 グリーン環境のインスタンスを再起動
アップグレード後のパラメータ適用を確実に行うため、グリーン環境のすべてのインスタンスを再起動します：

```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$GREEN_CLUSTER_ID" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  aws-vault exec mizzy -- aws rds reboot-db-instance \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1 >/dev/null
  echo "$instance_id を再起動中..."
done
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-cluster-green-xxxxxx-instance-1 を再起動中...
aurora-bg-aurora-cluster-green-xxxxxx-instance-2 を再起動中...
```

再起動完了まで待機：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=$GREEN_CLUSTER_ID" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  echo "$instance_id の再起動完了を待機中..."
  aws-vault exec mizzy -- aws rds wait db-instance-available \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1
  echo "$instance_id の再起動が完了しました"
done

echo "グリーン環境の全インスタンスの再起動が完了しました"
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-cluster-green-xxxxxx-instance-1 の再起動完了を待機中...
aurora-bg-aurora-cluster-green-xxxxxx-instance-1 の再起動が完了しました
aurora-bg-aurora-cluster-green-xxxxxx-instance-2 の再起動完了を待機中...
aurora-bg-aurora-cluster-green-xxxxxx-instance-2 の再起動が完了しました
グリーン環境の全インスタンスの再起動が完了しました
```

### 5. グリーン環境の検証（オプション）

グリーン環境のエンドポイントを使用して、アプリケーションの動作確認を行います。

```bash
GREEN_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $GREEN_CLUSTER_ID \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Endpoint' \
  --output text)
```

```bash
echo $GREEN_ENDPOINT
```

### 6. スイッチオーバーの実行

#### 6.1 スイッチオーバー前のスナップショット取得
スイッチオーバー前に、現在のBlue環境（本番環境）のスナップショットを取得します：

```bash
SNAPSHOT_ID="aurora-bg-aurora-cluster-before-switchover-$(date +%Y%m%d-%H%M%S)"

aws-vault exec mizzy -- aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier $SNAPSHOT_ID \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 >/dev/null

echo "スナップショット $SNAPSHOT_ID を作成中..."

aws-vault exec mizzy -- aws rds wait db-cluster-snapshot-completed \
  --db-cluster-snapshot-identifier $SNAPSHOT_ID \
  --region ap-northeast-1

echo "スナップショットの作成が完了しました"
```

**期待される出力例**:
```
スナップショット aurora-bg-aurora-cluster-before-switchover-20250115-110000 を作成中...
スナップショットの作成が完了しました
```

#### 6.2 スイッチオーバー前の最終確認
```bash
aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[0].[Status,StatusDetails]' \
  --output table
```

**期待される出力例**:
```
------------------------------
|DescribeBlueGreenDeployments|
+----------------------------+
|  AVAILABLE                 |
|  None                      |
+----------------------------+
```

この出力は正常な状態を示しています：
- `AVAILABLE`: スイッチオーバー可能な状態
- `None`: エラーや警告がない正常な状態

#### 6.3 スイッチオーバーを実行して完了を待機
**注意**: スイッチオーバーは通常数分で完了しますが、この間データベースへの接続が一時的に切断されます。

```bash
aws-vault exec mizzy -- aws rds switchover-blue-green-deployment \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 >/dev/null

echo "スイッチオーバーを開始しました"

while true; do
  STATUS=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
    --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
    --region ap-northeast-1 \
    --query 'BlueGreenDeployments[0].Status' \
    --output text)
  
  echo "$(date): ステータス = $STATUS"
  
  if [ "$STATUS" = "SWITCHOVER_COMPLETED" ]; then
    echo "スイッチオーバーが完了しました"
    break
  elif [ "$STATUS" = "SWITCHOVER_FAILED" ]; then
    echo "スイッチオーバーに失敗しました"
    exit 1
  fi
  
  sleep 30
done
```

**期待される出力例**:
```
スイッチオーバーを開始しました
Wed Jan 15 11:00:00 JST 2025: ステータス = SWITCHOVER_IN_PROGRESS
Wed Jan 15 11:00:30 JST 2025: ステータス = SWITCHOVER_IN_PROGRESS
Wed Jan 15 11:01:00 JST 2025: ステータス = SWITCHOVER_IN_PROGRESS
Wed Jan 15 11:01:30 JST 2025: ステータス = SWITCHOVER_IN_PROGRESS
Wed Jan 15 11:02:00 JST 2025: ステータス = SWITCHOVER_COMPLETED
スイッチオーバーが完了しました
```

### 7. アップグレード後の確認と再起動

#### 7.1 アップグレード後のクラスターバージョンを確認
```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].[DBClusterIdentifier,EngineVersion,Status]' \
  --output table
```

**期待される出力例**:
```
---------------------------------------------
|           DescribeDBClusters              |
+-------------------------------------------+
|  aurora-bg-aurora-cluster                 |
|  15.10                                    |
|  available                                |
+-------------------------------------------+
```

バージョンが `15.10` にアップグレードされていることを確認します。

#### 7.2 インスタンスのバージョンを確認
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,EngineVersion,DBInstanceStatus]' \
  --output table
```

**期待される出力例**（2インスタンスの場合）:
```
-------------------------------------------------------
|              DescribeDBInstances                    |
+------------------------------+---------+------------+
|  aurora-bg-aurora-instance-1 |  15.10  |  available |
|  aurora-bg-aurora-instance-2 |  15.10  |  available |
+------------------------------+---------+------------+
```

すべてのインスタンスが `15.10` にアップグレードされ、`available` 状態であることを確認します。

#### 7.3 インスタンスの再起動
スイッチオーバー後、パラメータグループの完全な同期のため、すべてのインスタンスを再起動します：

```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  aws-vault exec mizzy -- aws rds reboot-db-instance \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1 >/dev/null
  echo "$instance_id を再起動中..."
done
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1 を再起動中...
aurora-bg-aurora-instance-2 を再起動中...
```

再起動完了まで待機：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  echo "$instance_id の再起動完了を待機中..."
  aws-vault exec mizzy -- aws rds wait db-instance-available \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1
  echo "$instance_id の再起動が完了しました"
done

echo "全インスタンスの再起動が完了しました"
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1 の再起動完了を待機中...
aurora-bg-aurora-instance-1 の再起動が完了しました
aurora-bg-aurora-instance-2 の再起動完了を待機中...
aurora-bg-aurora-instance-2 の再起動が完了しました
全インスタンスの再起動が完了しました
```

#### 7.4 最終動作確認
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,EngineVersion]' \
  --output table
```

**期待される出力例**（2インスタンスの場合）:
```
-------------------------------------------------------
|              DescribeDBInstances                    |
+------------------------------+------------+---------+
|  aurora-bg-aurora-instance-1 |  available |  15.10  |
|  aurora-bg-aurora-instance-2 |  available |  15.10  |
+------------------------------+------------+---------+
```

すべてのインスタンスが再起動後も `available` 状態で、バージョン `15.10` で稼働していることを確認します。

### 8. Terraformコードの更新

スイッチオーバー完了後、Terraformコードのバージョンを更新して、実際の環境と一致させます。

#### 8.1 aurora.tfのバージョンを更新
```bash
# 現在のバージョンを確認
grep "engine_version" aurora.tf
```

aurora.tf を編集して、エンジンバージョンを更新：
```hcl
# 変更前
engine_version = "15.6"

# 変更後
engine_version = "15.10"
```

#### 8.2 Terraform実行計画を確認
```bash
terraform plan
```

**期待される出力**:
```
No changes. Your infrastructure matches the configuration.
```

もし差分が表示される場合は、以下を確認してください：
- インスタンス名が正しいか
- パラメータグループが正しく設定されているか
- その他の設定が実際の環境と一致しているか

#### 8.3 変更をコミット
```bash
git add aurora.tf
git commit -m "chore: Update Aurora PostgreSQL version from 15.6 to 15.10 after Blue/Green deployment"
```

### 9. ブルー/グリーン デプロイメントの削除

#### 9.1 ブルー/グリーン デプロイメントの削除
スイッチオーバー完了後、問題がないことを確認してから ブルー/グリーン デプロイメントを削除します。

```bash
aws-vault exec mizzy -- aws rds delete-blue-green-deployment \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 >/dev/null
```

**注意**: この時点で削除されるのはブルー/グリーン デプロイメントのリソースのみです。スイッチオーバー後に残された旧Blue環境（`aurora-bg-aurora-cluster-old1`）は自動的に削除されません。旧環境を削除する場合は、次の手順（9.2）で手動削除が必要です。

#### 9.2 旧環境の削除（オプション）

旧環境のインスタンスを削除：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster-old1" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  aws-vault exec mizzy -- aws rds delete-db-instance \
    --db-instance-identifier "$instance_id" \
    --skip-final-snapshot \
    --region ap-northeast-1 >/dev/null
  echo "$instance_id を削除中..."
done
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1-old1 を削除中...
aurora-bg-aurora-instance-2-old1 を削除中...
```

インスタンス削除完了まで待機：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster-old1" \
  --region ap-northeast-1 \
  --query 'DBInstances[*].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read instance_id; do
  echo "$instance_id の削除完了を待機中..."
  aws-vault exec mizzy -- aws rds wait db-instance-deleted \
    --db-instance-identifier "$instance_id" \
    --region ap-northeast-1
  echo "$instance_id の削除が完了しました"
done
```

**期待される出力例**（2インスタンスの場合）:
```
aurora-bg-aurora-instance-1-old1 の削除完了を待機中...
aurora-bg-aurora-instance-1-old1 の削除が完了しました
aurora-bg-aurora-instance-2-old1 の削除完了を待機中...
aurora-bg-aurora-instance-2-old1 の削除が完了しました
```

旧環境のクラスターを削除：
```bash
aws-vault exec mizzy -- aws rds delete-db-cluster \
  --db-cluster-identifier aurora-bg-aurora-cluster-old1 \
  --skip-final-snapshot \
  --region ap-northeast-1 >/dev/null
echo "aurora-bg-aurora-cluster-old1 を削除中..."
```

**期待される出力例**:
```
aurora-bg-aurora-cluster-old1 を削除中...
```

クラスター削除完了まで待機：
```bash
echo "クラスターの削除完了を待機中..."
aws-vault exec mizzy -- aws rds wait db-cluster-deleted \
  --db-cluster-identifier aurora-bg-aurora-cluster-old1 \
  --region ap-northeast-1
echo "aurora-bg-aurora-cluster-old1 の削除が完了しました"
```

**期待される出力例**:
```
クラスターの削除完了を待機中...
aurora-bg-aurora-cluster-old1 の削除が完了しました
```

---

## ロールバック手順

スイッチオーバー後に問題が発生した場合のロールバック手順については、以下のドキュメントを参照してください：

**[Aurora PostgreSQL ブルー/グリーン デプロイメント ロールバック手順書](./aurora-bg-rollback-procedure.md)**

---

## トラブルシューティング

### ブルー/グリーン デプロイメントのステータスが「PROVISIONING」で止まっている場合
- パラメータグループの互換性を確認
- セキュリティグループの設定を確認
- サブネットグループの設定を確認

### スイッチオーバーが失敗した場合
- CloudWatch Logs でエラーメッセージを確認
- RDS イベントログを確認：
```bash
aws-vault exec mizzy -- aws rds describe-events \
  --source-identifier aurora-bg-aurora-cluster \
  --source-type db-cluster \
  --region ap-northeast-1 \
  --duration 60
```

---

## 注意事項

1. **ダウンタイム**: スイッチオーバー中は短時間のダウンタイムが発生します（通常1-2分程度）
2. **接続文字列**: エンドポイントは変更されないため、アプリケーション側の変更は不要です
3. **パラメータグループ**: バージョンアップ後も同じパラメータグループファミリー（aurora-postgresql15）を使用できます
4. **バックアップ**: スイッチオーバー前に手動スナップショットの取得を推奨します
5. **テスト環境**: 本番環境での実施前に、テスト環境での検証を強く推奨します

---

## 参考情報

- [AWS Documentation: Blue/Green Deployments for Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/blue-green-deployments.html)
- [AWS CLI Reference: create-blue-green-deployment](https://docs.aws.amazon.com/cli/latest/reference/rds/create-blue-green-deployment.html)
- [AWS CLI Reference: switchover-blue-green-deployment](https://docs.aws.amazon.com/cli/latest/reference/rds/switchover-blue-green-deployment.html)