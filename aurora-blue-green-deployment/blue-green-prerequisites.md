# Aurora PostgreSQL ブルー/グリーン デプロイメント前提条件

## 必須パラメータ設定（AWS公式ドキュメント準拠）

### 1. 必須パラメータ
- `rds.logical_replication = 1` - 論理レプリケーションを有効化（**必須**）
- `synchronous_commit = on` - データ整合性を保証（**必須**）

### 2. ワーカープロセス設定
AWS公式ドキュメント（[Setting up logical replication](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Replication.Logical.Configure.html)）によると、以下のパラメータについて記載があります：

> "In many cases, the default values are sufficient."

以下のパラメータはデフォルト値で十分です：
- `max_replication_slots` - デフォルト値で十分
- `max_logical_replication_workers` - デフォルト値で十分  
- `max_worker_processes` - デフォルト値で十分（GREATEST(${DBInstanceVCPU*2},8)）

**参照**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Replication.Logical.Configure.html

### 3. 拡張機能の制限
**以下の拡張機能は無効にする必要があります：**
- `pglogical` - shared_preload_libraries から削除
- `pgactive` - 使用しない
- `pg_partman` - 使用しない
- `pg_cron` - Green環境では無効化

## データベース要件

### 1. プライマリキー
- **すべてのテーブルにプライマリキーが必要**
- プライマリキーがない場合は `REPLICA IDENTITY FULL` を設定

### 2. レプリケーションされない要素
以下は Blue から Green にレプリケーションされません：
- DDL文（CREATE TABLE, ALTER TABLE など）
- DCL文（GRANT, REVOKE など）
- シーケンス値
- ラージオブジェクト
- マテリアライズドビューの更新

## パフォーマンス考慮事項

### 1. 書き込み負荷
- 高い書き込みトラフィックはレプリケーション遅延を引き起こす可能性
- 必要に応じてインスタンスクラスをスケールアップ

### 2. データベース数
- データベース数が多いとリソースオーバーヘッドが増加

## 推奨事項

1. **事前テスト**: 本番環境での実施前に、テスト環境で十分に検証
2. **バックアップ**: Blue/Green デプロイメント作成前に手動スナップショットを取得
3. **監視**: レプリケーション遅延を監視
4. **タイミング**: 負荷の低い時間帯に実施

## 制限事項

### Aurora PostgreSQL バージョン
- Aurora PostgreSQL 10.13 以降が必要
- Babelfish は 15.7+ および 16.3+ でサポート

### 操作の制限
- 新しいパーティションの作成はサポートされない
- 論理レプリケーションの適用プロセスはシングルスレッド

## チェックリスト

ブルー/グリーン デプロイメント実施前の確認項目：

- [ ] `rds.logical_replication = 1` が設定されている
- [ ] pglogical 拡張機能が無効になっている
- [ ] すべてのテーブルにプライマリキーがある
- [ ] パラメータグループが正しく設定されている
- [ ] インスタンスが再起動済みで設定が反映されている
- [ ] 手動スナップショットを取得済み
- [ ] アプリケーションの停止計画が準備できている