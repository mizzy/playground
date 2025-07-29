import { Context } from "aws-lambda";
import { google } from "googleapis";
import { createGoogleAuth } from "./gcloudClient";

// Google Sheetsにアクセスするコア関数
async function accessGoogleSheets(spreadsheetId: string, range: string) {
  console.log(`Accessing spreadsheet: ${spreadsheetId}, range: ${range}`);

  // Google認証クライアントを作成
  const auth = await createGoogleAuth({
    scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"],
    workloadIdentityPoolProjectNumber: process.env.GCP_PROJECT_NUMBER,
    workloadIdentityPoolId: process.env.WORKLOAD_IDENTITY_POOL_ID,
    workloadIdentityPoolProviderId: process.env.WORKLOAD_IDENTITY_PROVIDER_ID,
    serviceAccountEmail: process.env.SERVICE_ACCOUNT_EMAIL,
    region: process.env.AWS_REGION || "ap-northeast-1",
  });

  // Sheets APIクライアントを作成
  const sheets = google.sheets({ version: "v4", auth });

  // スプレッドシートにアクセス
  console.log("Fetching spreadsheet data...");
  const response = await sheets.spreadsheets.values.get({
    spreadsheetId,
    range,
  });

  const data = response.data;
  const values = data.values || [];

  // 取得したセルの内容をログ出力
  console.log("Retrieved cell contents:");
  if (values.length === 0) {
    console.log("  (No data found in the specified range)");
  } else {
    values.forEach((row, rowIndex) => {
      console.log(`  Row ${rowIndex + 1}: ${JSON.stringify(row)}`);
    });
  }

  return {
    success: true,
    message: "Successfully accessed Google Sheets",
    spreadsheetId,
    range,
    majorDimension: data.majorDimension,
    rowCount: values.length,
    columnCount: values.length > 0 ? values[0].length : 0,
    values: values,
  };
}

// Lambdaハンドラー
export const handler = async (event: any, context?: Context): Promise<any> => {
  console.log("Lambda invoked with event:", JSON.stringify(event, null, 2));

  try {
    // 環境変数からスプレッドシートIDを取得
    const spreadsheetId = process.env.SPREADSHEET_ID;
    if (!spreadsheetId) {
      throw new Error("SPREADSHEET_ID environment variable is not set");
    }

    // イベントからrangeを取得、なければデフォルトを使用
    const range = event?.range || "A1:B10";

    const result = await accessGoogleSheets(spreadsheetId, range);
    return result;
  } catch (error: any) {
    console.error("Error accessing Google Sheets:", error);

    return {
      success: false,
      message: "Failed to access Google Sheets",
      error: error.message,
      details: error.response?.data || error.stack,
    };
  }
};

// 直接実行時のローカル実行処理
if (require.main === module) {
  (async () => {
    try {
      console.log("Running locally...");

      // 必要な環境変数をチェック
      if (!process.env.SPREADSHEET_ID) {
        console.error("Error: SPREADSHEET_ID environment variable is required");
        process.exit(1);
      }

      // コマンドライン引数からrangeを取得、なければデフォルトを使用
      const range = process.argv[2] || "A1:B10";

      // モックイベントでハンドラーを呼び出し
      const result = await handler({ range });

      console.log("\nResult:");
      console.log(JSON.stringify(result, null, 2));
    } catch (error) {
      console.error("Error:", error);
      process.exit(1);
    }
  })();
}
