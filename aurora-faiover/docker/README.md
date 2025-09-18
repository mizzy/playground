# TypeScript Application Docker Setup

## 概要
Node.js 22.19.0ベースのTypeScript実行環境をDockerコンテナとして構築し、ECRにプッシュするためのセットアップです。

## ファイル構成
- `Dockerfile` - TypeScript実行用のDockerイメージ定義
- `build-and-push.sh` - ECRへのビルド＆プッシュスクリプト
- `.dockerignore` - Docker除外ファイル設定

## 使用方法

### 1. Terraformでインフラストラクチャをデプロイ
```bash
cd ../terraform
terraform init
terraform plan
terraform apply
```

### 2. Dockerイメージをビルド＆ECRにプッシュ
```bash
# デフォルト（latestタグ）
./build-and-push.sh

# 特定のタグを指定
./build-and-push.sh v1.0.0
```

### 3. ローカルでのテスト実行
```bash
# イメージをビルド
docker build -t aurora-failover-ts .

# コンテナを実行（カレントディレクトリをマウント）
docker run -v $(pwd):/app aurora-failover-ts
```

## 前提条件
- AWS CLIが設定済み
- Dockerがインストール済み
- ECRリポジトリがTerraformで作成済み

## ECR設定
- イメージスキャン: 有効
- ライフサイクルポリシー:
  - タグ付きイメージは最新10個まで保持
  - 未タグイメージは1日後に削除
