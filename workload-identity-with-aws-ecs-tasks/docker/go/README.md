# Google Sheets Access Program

このGoプログラムは、Google Cloud Workload Identityを使用してGoogle Sheetsにアクセスします。

## 必要な環境変数

- `SPREADSHEET_ID`: アクセスするGoogle SheetsのスプレッドシートID
- `GOOGLE_APPLICATION_CREDENTIALS`: （オプション）サービスアカウントキーファイルのパス

## 実行方法

```bash
# 依存関係をインストール
go mod tidy

# 環境変数を設定してプログラムを実行
export SPREADSHEET_ID="your_spreadsheet_id_here"
go run main.go
```

## 機能

1. **スプレッドシート情報の取得**: 指定されたスプレッドシートの基本情報を表示
2. **データの読み取り**: 最初のシートのA1:E10範囲からデータを読み取り
3. **データの書き込み**: サンプルデータをA12:C12に書き込み

## Workload Identity設定

AWS ECSタスクでGoogle Cloud Workload Identityを使用する場合、以下の設定が必要です：

1. Google Cloud側でWorkload Identity Poolを設定
2. AWS IAMロールとGoogle Cloud Service Accountの信頼関係を設定
3. ECSタスクに適切なIAMロールを付与

## 権限

このプログラムを実行するには、以下のGoogle Sheets API権限が必要です：

- `https://www.googleapis.com/auth/spreadsheets` (読み書き権限)