# Pre-commit Hook Setup

このリポジトリではpre-commitフレームワークを使用してコード品質を保証しています。

## セットアップ手順

### 1. pre-commitのインストール

```bash
# pipを使用する場合
pip install pre-commit

# Homebrewを使用する場合 (macOS)
brew install pre-commit
```

### 2. Git hookのインストール

リポジトリのルートディレクトリで以下のコマンドを実行：

```bash
pre-commit install
```

これにより、`.pre-commit-config.yaml`に定義されたフックがgit commitの前に自動実行されます。

## 設定されているフック

- **terraform_fmt**: Terraformファイルのフォーマットチェック
- **end-of-file-fixer**: ファイル末尾に改行を確保
- **trailing-whitespace**: 行末の不要な空白を削除
- **check-yaml**: YAMLファイルの構文チェック
- **check-json**: JSONファイルの構文チェック
- **check-merge-conflict**: マージコンフリクトマーカーのチェック
- **check-case-conflict**: 大文字小文字を区別しないファイルシステムでの競合チェック

## 手動実行

すべてのファイルに対してフックを手動で実行する場合：

```bash
pre-commit run --all-files
```

特定のフックのみを実行する場合：

```bash
pre-commit run terraform_fmt --all-files
```

## トラブルシューティング

フックをスキップしてコミットする場合（非推奨）：

```bash
git commit --no-verify -m "your commit message"
```