# Aurora PostgreSQL 踏み台ECSタスク接続ガイド

## 重要な注意事項

⚠️ **既知の問題**: 現在、ECS Execでインタラクティブシェルセッションを維持する際にEOFエラーが発生する問題があります。これはAWS CLIまたはSession Manager Pluginの互換性の問題と思われます。

### 回避策
- 単一のコマンドは正常に実行可能です
- SQLファイルを使用したバッチ実行を推奨します
- psqlへの直接接続は一時的に可能ですが、セッションは短時間で切断される場合があります

## 概要
このドキュメントでは、ECS Fargateタスクを使用してAurora PostgreSQLデータベースに安全に接続する方法を説明します。

## 前提条件

### 必須ツール
- AWS CLI v2
- Session Manager プラグイン

### Session Manager プラグインのインストール

#### macOS
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

#### Linux
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

#### Windows
1. [Session Manager プラグインのダウンロード](https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe)
2. ダウンロードしたインストーラーを実行

## デプロイ手順

### 1. Terraformでインフラストラクチャをデプロイ

```bash
cd aurora-blue-green-deployment

# Terraformの初期化
terraform init

# プランの確認
terraform plan

# デプロイの実行
terraform apply
```

### 2. 出力値の確認

デプロイ完了後、以下のコマンドで接続に必要な情報を確認します：

```bash
# 接続に必要なコマンドを確認
terraform output bastion_run_task_command
terraform output bastion_connect_command
```

## 接続手順

### 方法1: ワンタイムタスクとして実行（推奨）

#### 1. ECSタスクを起動して接続（ワンライナー）

クラスター名とリージョンの設定:
```bash
export CLUSTER_NAME="aurora-bg-bastion-cluster"
export REGION="ap-northeast-1"
```

タスクを起動して自動的に接続:
TASK_ARN=$(aws-vault exec mizzy -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition aurora-bg-bastion \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json private_subnets | jq -r '.[].id' | paste -sd,)],securityGroups=[$(terraform output -raw bastion_security_group_id)],assignPublicIp=DISABLED}" \
  --enable-execute-command \
  --launch-type FARGATE \
  --region $REGION \
  --query 'tasks[0].taskArn' \
  --output text) && \
echo "Task started: $TASK_ARN" && \
echo "Waiting for task to be ready..." && \
aws-vault exec mizzy -- aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $REGION && \
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/bin/sh" \
  --region $REGION
```

#### 2. 個別ステップでの実行

##### タスクの起動と自動取得

クラスター名とリージョンの設定:
```bash
export CLUSTER_NAME="aurora-bg-bastion-cluster"
export REGION="ap-northeast-1"
```

Terraformから必要な値を自動取得してタスクを起動:
```bash
TASK_ARN=$(aws-vault exec mizzy -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition aurora-bg-bastion \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json private_subnets | jq -r '.[].id' | paste -sd,)],securityGroups=[$(terraform output -raw bastion_security_group_id)],assignPublicIp=DISABLED}" \
  --enable-execute-command \
  --launch-type FARGATE \
  --region $REGION \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Task ARN: $TASK_ARN"
```

##### タスクの状態確認

タスクが実行中になるまで待機:
```bash
aws-vault exec mizzy -- aws ecs wait tasks-running \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $REGION
```

タスクの詳細を確認:
```bash
aws-vault exec mizzy -- aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $REGION \
  --query 'tasks[0].{Status:lastStatus,DesiredStatus:desiredStatus,TaskArn:taskArn}'
```

##### タスクに接続

```bash
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/bin/sh" \
  --region $REGION
```

#### 3. PostgreSQLに接続

タスク内で以下のコマンドを実行：

```bash
psql
```

#### 4. タスクの自動停止

最新のタスクを自動的に停止:
```bash
LATEST_TASK=$(aws-vault exec mizzy -- aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --region $REGION \
  --query 'taskArns[0]' \
  --output text)

aws-vault exec mizzy -- aws ecs stop-task \
  --cluster $CLUSTER_NAME \
  --task $LATEST_TASK \
  --region $REGION \
  --query 'task.stoppedReason'
```

環境変数に保存されたタスクARNを使用:
```bash
aws-vault exec mizzy -- aws ecs stop-task \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --region $REGION
```

### 便利なスクリプト

#### bastion-connect.sh として保存
```bash
#!/bin/bash
set -e

# デフォルト値の設定
CLUSTER_NAME="${CLUSTER_NAME:-aurora-bg-bastion-cluster}"
REGION="${REGION:-ap-northeast-1}"

# カラー出力用の設定
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting ECS Bastion Task...${NC}"

# Terraformから値を取得
SUBNETS=$(terraform output -json private_subnets 2>/dev/null | jq -r '.[].id' | paste -sd,)
SECURITY_GROUP=$(terraform output -raw bastion_security_group_id 2>/dev/null)

if [ -z "$SUBNETS" ] || [ -z "$SECURITY_GROUP" ]; then
    echo -e "${YELLOW}Warning: Could not get values from Terraform. Using manual configuration.${NC}"
    echo "Please ensure you have run 'terraform apply' first."
    exit 1
fi

# タスクを起動
TASK_ARN=$(aws-vault exec mizzy -- aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition aurora-bg-bastion \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --enable-execute-command \
  --launch-type FARGATE \
  --region $REGION \
  --query 'tasks[0].taskArn' \
  --output text)

if [ -z "$TASK_ARN" ]; then
    echo "Failed to start task"
    exit 1
fi

echo -e "${GREEN}Task started: $TASK_ARN${NC}"
echo "Waiting for task to be ready..."

# タスクが実行中になるまで待機
aws-vault exec mizzy -- aws ecs wait tasks-running --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $REGION

echo -e "${GREEN}Connecting to task...${NC}"
echo "Type 'psql' to connect to PostgreSQL"
echo "Type 'exit' to disconnect and stop the task"

# タスクに接続
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/bin/sh" \
  --region $REGION

# 接続終了後、タスクを停止
echo -e "${YELLOW}Stopping task...${NC}"
aws-vault exec mizzy -- aws ecs stop-task \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --region $REGION \
  --output text > /dev/null

echo -e "${GREEN}Task stopped successfully${NC}"
```

使用方法：

スクリプトに実行権限を付与:
```bash
chmod +x bastion-connect.sh
```

実行:
```bash
./bastion-connect.sh
```

### 方法2: ECSサービスとして常時起動

#### 1. variables.tfでサービスを有効化

variables.tf または terraform.tfvars で設定:
```hcl
bastion_enable_service = true
bastion_service_desired_count = 1
```

#### 2. Terraformを再適用

```bash
terraform apply
```

#### 3. 実行中のタスクに自動接続

環境変数の設定:
```bash
export CLUSTER_NAME="aurora-bg-bastion-cluster"
export SERVICE_NAME="aurora-bg-bastion-service"
export REGION="ap-northeast-1"
```

サービスから実行中のタスクを取得して接続:
```bash
TASK_ARN=$(aws-vault exec mizzy -- aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $REGION \
  --query 'taskArns[0]' \
  --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
  aws-vault exec mizzy -- aws ecs execute-command \
    --cluster $CLUSTER_NAME \
    --task $TASK_ARN \
    --container bastion \
    --interactive \
    --command "/bin/sh" \
    --region $REGION
else
  echo "No running tasks found for service $SERVICE_NAME"
fi
```

## PostgreSQL操作例

### 基本的な接続確認
```sql
-- PostgreSQLエンジンバージョンの確認
SELECT version();

-- Aurora PostgreSQLの詳細バージョン確認
SHOW server_version;

-- Aurora固有の拡張機能バージョン確認
SELECT aurora_version();

-- 現在のデータベース確認
SELECT current_database();

-- 接続情報の確認
\conninfo

-- テーブル一覧
\dt

-- データベース一覧
\l

-- ユーザー一覧
\du
```

### テーブル作成とデータ操作の実践

#### 1. サンプルテーブルの作成

usersテーブルの作成:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

ordersテーブルの作成:
```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    order_date DATE DEFAULT CURRENT_DATE,
    total_amount DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

インデックスの作成:
```sql
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(order_date);
```

#### 2. データの挿入

usersテーブルへのデータ挿入:
```sql
INSERT INTO users (username, email, full_name) VALUES
    ('tanaka_taro', 'tanaka@example.com', '田中太郎'),
    ('sato_hanako', 'sato@example.com', '佐藤花子'),
    ('suzuki_ichiro', 'suzuki@example.com', '鈴木一郎'),
    ('yamada_yuki', 'yamada@example.com', '山田由紀'),
    ('kobayashi_ken', 'kobayashi@example.com', '小林健');
```

ordersテーブルへのデータ挿入:
```sql
INSERT INTO orders (user_id, order_date, total_amount, status, notes) VALUES
    (1, '2024-01-15', 15000.00, 'completed', '初回購入'),
    (1, '2024-02-20', 8500.50, 'completed', 'リピート購入'),
    (2, '2024-01-20', 22000.00, 'completed', '大口注文'),
    (3, '2024-03-01', 5500.00, 'processing', '配送中'),
    (4, '2024-03-10', 12000.00, 'pending', '決済待ち'),
    (5, '2024-03-15', 9800.00, 'completed', '優良顧客'),
    (1, '2024-03-18', 18000.00, 'processing', '特別注文'),
    (2, '2024-03-20', 7500.00, 'pending', NULL);
```

大量データの挿入（パフォーマンステスト用）:
```sql
INSERT INTO orders (user_id, order_date, total_amount, status)
SELECT
    (random() * 4 + 1)::int,
    CURRENT_DATE - (random() * 365)::int,
    (random() * 50000 + 1000)::decimal(10,2),
    CASE (random() * 3)::int
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'processing'
        ELSE 'completed'
    END
FROM generate_series(1, 100);
```

#### 3. データの読み取り（基本クエリ）

全ユーザーの確認:
```sql
SELECT * FROM users;
```

特定ユーザーの注文履歴:
```sql
SELECT
    u.full_name,
    o.order_date,
    o.total_amount,
    o.status
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE u.username = 'tanaka_taro'
ORDER BY o.order_date DESC;
```

ステータス別の注文数と合計金額:
```sql
SELECT
    status,
    COUNT(*) as order_count,
    SUM(total_amount) as total_sales,
    AVG(total_amount) as avg_order_value
FROM orders
GROUP BY status;
```

#### 4. 高度なクエリ操作

月別売上集計:
```sql
SELECT
    DATE_TRUNC('month', order_date) as month,
    COUNT(*) as order_count,
    SUM(total_amount) as monthly_sales,
    AVG(total_amount) as avg_order_value
FROM orders
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month DESC;
```

ユーザー別の購買分析:
```sql
SELECT
    u.full_name,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.full_name
ORDER BY total_spent DESC NULLS LAST;
```

ウィンドウ関数を使用した累計売上:
```sql
SELECT
    order_date,
    total_amount,
    SUM(total_amount) OVER (ORDER BY order_date) as running_total,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date) as user_order_num
FROM orders
WHERE status = 'completed'
ORDER BY order_date;
```

CTEを使用した複雑なクエリ:
```sql
WITH user_stats AS (
    SELECT
        user_id,
        COUNT(*) as order_count,
        SUM(total_amount) as total_spent,
        AVG(total_amount) as avg_spent
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
user_categories AS (
    SELECT
        user_id,
        CASE
            WHEN total_spent > 50000 THEN 'VIP'
            WHEN total_spent > 20000 THEN 'Gold'
            WHEN total_spent > 10000 THEN 'Silver'
            ELSE 'Regular'
        END as customer_tier
    FROM user_stats
)
SELECT
    u.full_name,
    us.order_count,
    us.total_spent,
    uc.customer_tier
FROM users u
JOIN user_stats us ON u.id = us.user_id
JOIN user_categories uc ON u.id = uc.user_id
ORDER BY us.total_spent DESC;
```

#### 5. データの更新と削除

特定条件でのデータ更新:
```sql
UPDATE orders
SET status = 'completed',
    updated_at = CURRENT_TIMESTAMP
WHERE status = 'processing'
  AND order_date < CURRENT_DATE - INTERVAL '7 days';
```

ユーザー情報の更新:
```sql
UPDATE users
SET email = 'new_email@example.com',
    updated_at = CURRENT_TIMESTAMP
WHERE username = 'tanaka_taro';
```

古いデータの削除（慎重に実行）:
```sql
DELETE FROM orders
WHERE order_date < CURRENT_DATE - INTERVAL '2 years'
  AND status = 'completed';
```

トランザクションを使用した安全な更新:
```sql
BEGIN;
    UPDATE orders SET total_amount = total_amount * 1.1
    WHERE status = 'pending';

    SELECT COUNT(*), SUM(total_amount)
    FROM orders
    WHERE status = 'pending';

    COMMIT;
```

#### 6. パフォーマンス分析

クエリ実行計画の確認:
```sql
EXPLAIN ANALYZE
SELECT u.*, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id;
```

テーブル統計の確認:
```sql
SELECT
    schemaname,
    tablename,
    n_live_tup as row_count,
    n_dead_tup as dead_rows,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE schemaname = 'public';
```

インデックス使用状況の確認:
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### 7. データのエクスポート

CSVとしてデータをエクスポート（psqlから実行）:
```sql
\copy (SELECT * FROM users) TO '/tmp/users_export.csv' WITH CSV HEADER;
\copy (SELECT * FROM orders WHERE status = 'completed') TO '/tmp/completed_orders.csv' WITH CSV HEADER;
```

JSON形式でのエクスポート（PostgreSQL 9.3+）:
```sql
SELECT json_agg(users) FROM users;
```

特定形式でのエクスポート:
```sql
\copy (
    SELECT
        u.full_name as "顧客名",
        COUNT(o.id) as "注文数",
        SUM(o.total_amount) as "合計購入額"
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
    GROUP BY u.id, u.full_name
) TO '/tmp/customer_summary.csv' WITH CSV HEADER ENCODING 'UTF8';
```

### バックアップとリストア

タスク内でバックアップ:
```bash
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > /tmp/backup.sql
```

リストア:
```bash
psql -h $PGHOST -U $PGUSER -d $PGDATABASE < /tmp/backup.sql
```

### データ移行やメンテナンス

CSVエクスポート:
```bash
psql -c "COPY (SELECT * FROM your_table) TO STDOUT WITH CSV HEADER" > /tmp/export.csv
```

CSVインポート:
```bash
psql -c "COPY your_table FROM STDIN WITH CSV HEADER" < /tmp/import.csv
```

### 既知の問題への対処法

#### 単一コマンドの実行（推奨）

インタラクティブシェルが不安定な場合、単一コマンドとして実行します：

```bash
# SQLコマンドを直接実行
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster aurora-bg-bastion-cluster \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/usr/bin/psql -c 'SELECT current_database();'" \
  --region ap-northeast-1

# SQLファイルの実行
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster aurora-bg-bastion-cluster \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/usr/bin/psql -f /tmp/script.sql" \
  --region ap-northeast-1
```

#### バッチ処理スクリプトの使用

複数のSQLコマンドを実行する場合：

```bash
# タスク内でスクリプトを作成
cat << 'EOF' > /tmp/batch_sql.sh
#!/bin/bash
psql << SQL
CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO test_table (name) VALUES ('test1'), ('test2');
SELECT * FROM test_table;
DROP TABLE test_table;
SQL
EOF

# スクリプトを実行
aws-vault exec mizzy -- aws ecs execute-command \
  --cluster aurora-bg-bastion-cluster \
  --task $TASK_ARN \
  --container bastion \
  --interactive \
  --command "/bin/bash /tmp/batch_sql.sh" \
  --region ap-northeast-1
```

## セキュリティベストプラクティス

### 1. 最小権限の原則
- ECSタスクロールには必要最小限の権限のみを付与
- データベースユーザーも必要最小限の権限で作成

### 2. 一時的なアクセス
- ワンタイムタスクとして実行し、作業完了後は必ず停止
- 常時起動のサービスは開発環境のみで使用

### 3. 監査ログ
- CloudWatch Logsでセッションログを確認
- AWS CloudTrailでAPI呼び出しを監査

### 4. ネットワーク分離
- プライベートサブネットでのみ実行
- セキュリティグループで厳密にアクセス制御

## トラブルシューティング

### タスクが起動しない

タスクの失敗理由を確認:
```bash
aws-vault exec mizzy -- aws ecs describe-tasks \
  --cluster aurora-bg-bastion-cluster \
  --tasks <TASK_ARN> \
  --region ap-northeast-1 \
  --query 'tasks[0].stoppedReason'
```

### Session Managerに接続できない
1. Session Manager プラグインがインストールされているか確認
2. IAMロールに必要な権限があるか確認
3. VPCエンドポイントが設定されているか確認（プライベートサブネットの場合）

### PostgreSQLに接続できない
1. セキュリティグループの設定を確認
2. Aurora クラスターのステータスを確認
3. データベース認証情報を確認

## リソースのクリーンアップ

```bash
# ECSサービスを停止（サービスモードの場合）
terraform apply -var="bastion_enable_service=false"

# すべてのリソースを削除
terraform destroy
```

## 参考情報

- [AWS ECS Execute Command](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
- [Session Manager プラグイン](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [Aurora PostgreSQL ドキュメント](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraPostgreSQL.html)
