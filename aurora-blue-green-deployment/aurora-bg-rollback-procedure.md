# Aurora PostgreSQL ブルー/グリーン デプロイメント ロールバック手順書

## 概要
ブルー/グリーン デプロイメントによるスイッチオーバー後に問題が発生した場合のロールバック手順を説明します。

## ロールバック方法の選択

以下の2つの方法があります：
- **方法A**: 簡易ロールバック（スイッチオーバー後にデータが書き込まれていない、またはデータの巻き戻りが許容される場合）
- **方法B**: 完全なロールバック（スイッチオーバー後のデータを保持する必要がある場合）

---

## 方法A: ブルー/グリーンデプロイメントのスイッチバック（スイッチオーバー後にデータが書き込まれていない、またはデータの巻き戻りが許容される場合）

**注意**: この方法では、スイッチオーバー後に書き込まれたデータはすべて失われます。旧環境（-old1）が削除されていない場合のみ使用可能です。

### オプション1: AWS ブルー/グリーンデプロイメントのスイッチバック機能を使用

ブルー/グリーンデプロイメントがまだ削除されていない場合、スイッチバック機能を使用できます：

```bash
# ブルー/グリーンデプロイメントの確認
aws-vault exec mizzy -- aws rds describe-blue-green-deployments \
  --region ap-northeast-1 \
  --query 'BlueGreenDeployments[*].[BlueGreenDeploymentIdentifier,BlueGreenDeploymentName,Status]' \
  --output table

# スイッチバックの実行（デプロイメントIDを指定）
DEPLOYMENT_ID="<ブルー/グリーンデプロイメントID>"

aws-vault exec mizzy -- aws rds switchover-blue-green-deployment \
  --blue-green-deployment-identifier $DEPLOYMENT_ID \
  --switchover-timeout 300 \
  --region ap-northeast-1

echo "スイッチバックを実行中..."

# スイッチバックの完了を待機
aws-vault exec mizzy -- aws rds wait blue-green-deployment-available \
  --blue-green-deployment-identifier $DEPLOYMENT_ID \
  --region ap-northeast-1

echo "スイッチバックが完了しました"
```

**メリット**:
- AWS管理のプロセスで安全にロールバック可能
- エンドポイントは自動的に元に戻る
- 手動での名前変更が不要

### オプション2: 手動での名前入れ替え（ブルー/グリーンデプロイメントが削除済みの場合）

ブルー/グリーンデプロイメントが既に削除されている場合は、以下の手動手順を使用します：

### 1. 現在のクラスター名を確認
```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --region ap-northeast-1 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `aurora-bg-aurora-cluster`)].[DBClusterIdentifier,EngineVersion,Status]' \
  --output table
```

### 2. 旧環境へ名前を入れ替え
```bash
# 現在のクラスター（15.10）を一時的な名前に変更
aws-vault exec mizzy -- aws rds modify-db-cluster \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --new-db-cluster-identifier aurora-bg-aurora-cluster-temp \
  --apply-immediately \
  --region ap-northeast-1 >/dev/null

echo "現在のクラスターを一時名に変更中..."

# 旧環境（15.6）を元の名前に戻す
aws-vault exec mizzy -- aws rds modify-db-cluster \
  --db-cluster-identifier aurora-bg-aurora-cluster-old1 \
  --new-db-cluster-identifier aurora-bg-aurora-cluster \
  --apply-immediately \
  --region ap-northeast-1 >/dev/null

echo "旧環境を元の名前に戻しました"
```

### 3. インスタンス名も同様に入れ替え
```bash
# 現在のインスタンスを一時名に変更
for i in 1 2; do
  aws-vault exec mizzy -- aws rds modify-db-instance \
    --db-instance-identifier aurora-bg-aurora-instance-$i \
    --new-db-instance-identifier aurora-bg-aurora-instance-$i-temp \
    --apply-immediately \
    --region ap-northeast-1 >/dev/null
  echo "aurora-bg-aurora-instance-$i を一時名に変更中..."
done

# 旧環境のインスタンスを元の名前に戻す
for i in 1 2; do
  aws-vault exec mizzy -- aws rds modify-db-instance \
    --db-instance-identifier aurora-bg-aurora-instance-$i-old1 \
    --new-db-instance-identifier aurora-bg-aurora-instance-$i \
    --apply-immediately \
    --region ap-northeast-1 >/dev/null
  echo "aurora-bg-aurora-instance-$i-old1 を元の名前に戻しています..."
done
```

### 4. 変更の完了を待機
```bash
for i in 1 2; do
  aws-vault exec mizzy -- aws rds wait db-instance-available \
    --db-instance-identifier aurora-bg-aurora-instance-$i \
    --region ap-northeast-1
  echo "aurora-bg-aurora-instance-$i が利用可能になりました"
done

echo "ロールバックが完了しました（バージョン15.6に戻りました）"
```

**重要**: この方法ではエンドポイントは変更されませんが、スイッチオーバー後のデータはすべて失われます。

---

## 方法B: 完全なロールバック（スイッチオーバー後のデータを保持する必要がある場合）

スイッチオーバー後に書き込まれたデータを保持する必要がある場合は、スナップショットからの復元が必要です。

### 1. データベースへのアクセスを停止

クラスターを停止してアクセスを遮断：
```bash
aws-vault exec mizzy -- aws rds stop-db-cluster \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 >/dev/null

echo "クラスターを停止中..."

aws-vault exec mizzy -- aws rds wait db-cluster-stopped \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1

echo "クラスターが停止しました"
```

### 2. 現在の状態のスナップショットを作成

```bash
SNAPSHOT_ID="aurora-bg-aurora-cluster-rollback-$(date +%Y%m%d-%H%M%S)"

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

### 3. スイッチオーバー前のスナップショットを確認

```bash
aws-vault exec mizzy -- aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table
```

### 4. スナップショットからの復元（実際のロールバック）

#### 4.1 既存クラスターのインスタンスを削除
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
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

インスタンス削除完了まで待機：
```bash
aws-vault exec mizzy -- aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=aurora-bg-aurora-cluster" \
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

#### 4.2 既存クラスターを削除
```bash
aws-vault exec mizzy -- aws rds delete-db-cluster \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --skip-final-snapshot \
  --region ap-northeast-1 >/dev/null
echo "aurora-bg-aurora-cluster を削除中..."

aws-vault exec mizzy -- aws rds wait db-cluster-deleted \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1
echo "aurora-bg-aurora-cluster の削除が完了しました"
```

#### 4.3 スナップショットから同じ名前で復元
```bash
RESTORE_SNAPSHOT_ID="<復元したいスナップショットID>"

aws-vault exec mizzy -- aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --snapshot-identifier $RESTORE_SNAPSHOT_ID \
  --engine aurora-postgresql \
  --db-subnet-group-name aurora-bg-aurora-subnet-group \
  --db-cluster-parameter-group-name aurora-bg-aurora-pg15-cluster-params \
  --vpc-security-group-ids $(aws-vault exec mizzy -- aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=aurora-bg-aurora-sg" \
    --region ap-northeast-1 \
    --query 'SecurityGroups[0].GroupId' \
    --output text) \
  --region ap-northeast-1 >/dev/null

echo "クラスターを復元中..."

aws-vault exec mizzy -- aws rds wait db-cluster-available \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1

echo "クラスターの復元が完了しました"
```

#### 4.4 インスタンスを作成
```bash
for i in 1 2; do
  aws-vault exec mizzy -- aws rds create-db-instance \
    --db-instance-identifier aurora-bg-aurora-instance-$i \
    --db-cluster-identifier aurora-bg-aurora-cluster \
    --db-instance-class db.t4g.medium \
    --engine aurora-postgresql \
    --db-parameter-group-name aurora-bg-aurora-pg15-params \
    --region ap-northeast-1 >/dev/null
  echo "aurora-bg-aurora-instance-$i を作成中..."
done

for i in 1 2; do
  aws-vault exec mizzy -- aws rds wait db-instance-available \
    --db-instance-identifier aurora-bg-aurora-instance-$i \
    --region ap-northeast-1
  echo "aurora-bg-aurora-instance-$i の作成が完了しました"
done
```

#### 4.5 新しいエンドポイントを確認
**重要**: 同じクラスター名で復元しても、エンドポイントのドメイン名は変更されます。

```bash
aws-vault exec mizzy -- aws rds describe-db-clusters \
  --db-cluster-identifier aurora-bg-aurora-cluster \
  --region ap-northeast-1 \
  --query 'DBClusters[0].[Endpoint,ReaderEndpoint]' \
  --output table
```

### エンドポイントを変更したくない場合の対策

以下のいずれかの方法を事前に実装しておくことを推奨します：

1. **Route 53 CNAMEレコードを使用**（推奨）
   - 独自ドメインのCNAMEレコードを作成し、Auroraエンドポイントを指すように設定
   - アプリケーションは独自ドメイン名で接続
   - ロールバック時はCNAMEレコードの向き先を更新するだけ

2. **別名で復元して、ブルー/グリーン デプロイメントで切り替え**
   - 別のクラスター名で復元（例: aurora-bg-aurora-cluster-rollback）
   - 新たにブルー/グリーン デプロイメントを作成してスイッチオーバー
   - ただし、この方法でもエンドポイントは変更される可能性があります

---

## 注意事項

1. **データの整合性**: 方法Aではデータが失われるため、必ず事前に影響を確認してください
2. **エンドポイント**: 方法Bではエンドポイントが変更されるため、アプリケーション側の設定変更が必要になる場合があります
3. **スナップショット**: ロールバック前に必ず現在の状態のスナップショットを取得してください
4. **テスト**: 本番環境でのロールバック前に、可能であればテスト環境で手順を確認してください