# Aurora PostgreSQL ブルー/グリーン デプロイメントによるバージョンアップ手順書

## 概要
本手順書では、Aurora PostgreSQL クラスターを 15.6 から 15.10 へ、ブルー/グリーン デプロイメントを使用してアップグレードする手順を説明します。

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

#### 1.1 現在のクラスターのバージョンとステータスを確認
```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].[DBClusterIdentifier,EngineVersion,Status]' \
  --output table
```

**期待される出力例**:
```
-----------------------------------------
|         DescribeDBClusters            |
+---------------------------------------+
|  aurora-bg-aurora-cluster             |
|  15.6                                 |
|  available                            |
+---------------------------------------+
```

**確認事項**:
- [ ] クラスター識別子が `aurora-bg-aurora-cluster` である
- [ ] 現在のバージョンが `15.6` である
- [ ] ステータスが `available` である

#### 1.2 現在のインスタンスのバージョンとステータスを確認
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
|  aurora-bg-aurora-instance-1 |  15.6   |  available |
|  aurora-bg-aurora-instance-2 |  15.6   |  available |
+------------------------------+---------+------------+
```

**確認事項**:
- [ ] すべてのインスタンスが表示されている
- [ ] すべてのインスタンスのバージョンが `15.6` である
- [ ] すべてのインスタンスのステータスが `available` である

#### 1.3 ターゲットバージョン（15.10）の利用可能性を確認
```bash
aws-vault exec mizzy -- aws rds describe-db-engine-versions \
  --engine aurora-postgresql \
  --engine-version 15.10 \
  --region ap-northeast-1 \
  --query 'DBEngineVersions[0].[Engine,EngineVersion,DBParameterGroupFamily]' \
  --output table
```

**期待される出力例**:
```
----------------------------------------------------
|          DescribeDBEngineVersions                |
+--------------------------------------------------+
|  aurora-postgresql                              |
|  15.10                                          |
|  aurora-postgresql15                            |
+--------------------------------------------------+
```

**確認事項**:
- [ ] バージョン `15.10` が表示されている
- [ ] パラメータグループファミリーが `aurora-postgresql15` である

### 2. 論理レプリケーションの有効化

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
aurora-bg-aurora-instance-1 の再起動完了を待機中...
aurora-bg-aurora-instance-1 の再起動が完了しました
aurora-bg-aurora-instance-2 の再起動完了を待機中...
aurora-bg-aurora-instance-2 の再起動が完了しました
全インスタンスの再起動が完了しました
```

**確認事項**:
- [ ] すべてのインスタンスの再起動が完了した

### 3. ブルー/グリーン デプロイメントの作成

#### 3.1 クラスターARNをシェル変数にセット
ブルー/グリーン デプロイメント作成に必要なクラスターARNを取得してシェル変数にセットします：

```bash
CLUSTER_ARN=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].DBClusterArn' \
  --output text)

echo $CLUSTER_ARN
```

**確認事項**:
- [ ] クラスターARNがシェル変数`CLUSTER_ARN`にセットされた

#### 3.2 ブルー/グリーン デプロイメントを作成
15.10へのアップグレード用のブルー/グリーン デプロイメントを作成して、デプロイメントIDをシェル変数にセットします：

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

echo $BG_DEPLOYMENT_ID
```

**確認事項**:
- [ ] デプロイメントIDがシェル変数`BG_DEPLOYMENT_ID`にセットされた

#### 3.3 デプロイメントのステータスを確認
作成したブルー/グリーン デプロイメントの初期ステータスを確認します：

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

**確認事項**:
- [ ] ステータスが `PROVISIONING` である

#### 3.4 デプロイメントが利用可能になるまで待機

> [!WARNING]
> グリーン環境の作成には時間がかかります（データベースのサイズやインスタンス数により30分〜1時間以上）。

ステータスが`AVAILABLE`になるまで定期的にチェックします：

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

**確認事項**:
- [ ] ステータスが `AVAILABLE` になった

### 4. グリーン環境の再起動

グリーン環境作成後のパラメータ適用を確実に行うため、グリーン環境のすべてのインスタンスを再起動します。

#### 4.1 グリーン環境のクラスター識別子を取得
グリーン環境のクラスターARNから識別子を抽出してシェル変数にセットします：

```bash
GREEN_CLUSTER_ARN=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[0].Target' \
  --output text)

GREEN_CLUSTER_ID=$(echo $GREEN_CLUSTER_ARN | awk -F: '{print $NF}')

echo $GREEN_CLUSTER_ID
```

**確認事項**:
- [ ] グリーン環境のクラスター識別子がシェル変数`GREEN_CLUSTER_ID`にセットされた

#### 4.2 グリーン環境のインスタンスを再起動
クラスター内のすべてのインスタンスを個別に再起動します：

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

**確認事項**:
- [ ] すべてのグリーン環境インスタンスの再起動が完了した

### 5. グリーン環境の検証（オプション）

グリーン環境のエンドポイントを取得して、必要に応じてアプリケーションの動作確認を行います：

```bash
GREEN_ENDPOINT=$(aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier $GREEN_CLUSTER_ID \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Endpoint' \
  --output text)

echo $GREEN_ENDPOINT
```

### 6. スイッチオーバーの実行

#### 6.1 スイッチオーバー前のスナップショット取得
スイッチオーバー前に、現在のブルー環境（本番環境）のスナップショットを取得してバックアップを作成します。

まず、クラスターが利用可能な状態であることを確認：
```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].Status' \
  --output text
```

**期待される出力**:
```
available
```

ステータスが`available`であることを確認してから、スナップショットを作成：

```bash
SNAPSHOT_ID="aurora-bg-aurora-cluster-before-switchover-$(date +%Y%m%d-%H%M%S)"

aws-vault exec mizzy -- aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier $SNAPSHOT_ID \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 >/dev/null

echo "スナップショット $SNAPSHOT_ID の作成を開始しました"
echo "（クラスターは一時的にbacking-up状態になります）"
```

**期待される出力例**:
```
スナップショット aurora-bg-aurora-cluster-before-switchover-20250115-110000 の作成を開始しました
（クラスターは一時的にbacking-up状態になります）
```

スナップショット作成後、クラスターは一時的に`backing-up`状態になります。`available`状態に戻るまで待機：
```bash
echo "ブルー環境のクラスターが利用可能になるまで待機中..."
echo "（スナップショット作成によりbacking-up状態からavailable状態に戻るのを待っています）"
aws-vault exec mizzy -- aws rds wait db-cluster-available \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1
echo "ブルー環境のクラスターが利用可能になりました"
```

**期待される出力例**:
```
ブルー環境のクラスターが利用可能になるまで待機中...
（スナップショット作成によりbacking-up状態からavailable状態に戻るのを待っています）
ブルー環境のクラスターが利用可能になりました
```

**確認事項**:
- [ ] スナップショットの作成を開始した
- [ ] クラスターが`available`状態に戻った

#### 6.2 スイッチオーバー前の最終確認
ブルー/グリーン デプロイメントがスイッチオーバー可能な状態であることを確認します：

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

**確認事項**:
- [ ] ステータスが `AVAILABLE` である
- [ ] StatusDetailsが `None` である

#### 6.3 スイッチオーバーを実行して完了を待機

> [!IMPORTANT]
> スイッチオーバーは通常数分で完了しますが、この間データベースへの接続が一時的に切断されます。

ブルー環境とグリーン環境を切り替え、グリーン環境を新しい本番環境にします：

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

**確認事項**:
- [ ] ステータスが `SWITCHOVER_COMPLETED` になった

### 7. スイッチオーバー後の確認

#### 7.1 スイッチオーバー後のクラスターバージョンを確認
スイッチオーバー完了後、クラスターが正しくアップグレードされたことを確認します：

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

**確認事項**:
- [ ] バージョンが `15.10` にアップグレードされている
- [ ] ステータスが `available` である

#### 7.2 インスタンスのバージョンを確認
すべてのインスタンスもアップグレードされていることを確認します：

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

**確認事項**:
- [ ] すべてのインスタンスが `15.10` にアップグレードされている
- [ ] すべてのインスタンスのステータスが `available` である

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

**確認事項**:
- [ ] Terraformの設定と実際の環境に差分がない

#### 8.3 変更をコミット
```bash
git add aurora.tf
git commit -m "chore: Update Aurora PostgreSQL version from 15.6 to 15.10 after Blue/Green deployment"
```

### 9. ブルー/グリーン デプロイメントの削除

時間をおいて実行する場合は、まずブルー/グリーン デプロイメントIDを取得します：

```bash
BG_DEPLOYMENT_ID=$(aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[?Status==`SWITCHOVER_COMPLETED`].BlueGreenDeploymentIdentifier' \
  --output text)

echo "ブルー/グリーン デプロイメントID: $BG_DEPLOYMENT_ID"
```

**期待される出力例**:
```
ブルー/グリーン デプロイメントID: bgd-xxxxxxxxxxxxxxx
```

#### 9.1 ブルー/グリーン デプロイメントの削除
スイッチオーバー完了後、問題がないことを確認してから ブルー/グリーン デプロイメントのリソースを削除します：

```bash
aws-vault exec mizzy -- aws rds delete-blue-green-deployment \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 >/dev/null
```

削除を確認：
```bash
aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --blue-green-deployment-identifier $BG_DEPLOYMENT_ID \
  --region ap-northeast-1 2>&1 | grep -q "BlueGreenDeploymentNotFoundFault" && \
  echo "ブルー/グリーン デプロイメントが削除されました" || \
  echo "削除処理中..."
```

**期待される出力例**:
```
ブルー/グリーン デプロイメントが削除されました
```

**確認事項**:
- [ ] ブルー/グリーン デプロイメントのリソースが削除された

#### 9.2 旧環境のインスタンスを削除

スイッチオーバー後に残された旧ブルー環境のインスタンスを削除します：
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

**確認事項**:
- [ ] すべての旧環境インスタンスが削除された

#### 9.3 旧環境のクラスターを削除

インスタンス削除後、旧ブルー環境のクラスターを削除します：
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

**確認事項**:
- [ ] 旧環境のクラスターが削除された

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

> [!IMPORTANT]
> **ダウンタイム**: スイッチオーバー中は短時間のダウンタイムが発生します（通常1-2分程度）

> [!NOTE]
> **接続文字列**: エンドポイントは変更されないため、アプリケーション側の変更は不要です

> [!NOTE]
> **パラメータグループ**: バージョンアップ後も同じパラメータグループファミリー（aurora-postgresql15）を使用できます

> [!WARNING]
> **バックアップ**: スイッチオーバー前に手動スナップショットの取得を推奨します

> [!CAUTION]
> **テスト環境**: 本番環境での実施前に、テスト環境での検証を強く推奨します

---

## 参考情報

- [AWS Documentation: Blue/Green Deployments for Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/blue-green-deployments.html)
- [AWS CLI Reference: create-blue-green-deployment](https://docs.aws.amazon.com/cli/latest/reference/rds/create-blue-green-deployment.html)
- [AWS CLI Reference: switchover-blue-green-deployment](https://docs.aws.amazon.com/cli/latest/reference/rds/switchover-blue-green-deployment.html)