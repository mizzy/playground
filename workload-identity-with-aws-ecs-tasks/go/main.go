package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"golang.org/x/oauth2/google"
	"google.golang.org/api/impersonate"
	"google.golang.org/api/option"
	"google.golang.org/api/sheets/v4"
)

func main() {
	ctx := context.Background()

	// gosukenator@gmail.comアカウントでspreadsheet-service-accountにimpersonateして認証
	baseCredentials, err := google.FindDefaultCredentials(ctx, "https://www.googleapis.com/auth/cloud-platform")
	if err != nil {
		log.Fatalf("ベース認証情報の取得に失敗しました: %v", err)
	}

	// プロジェクトIDを取得（環境変数から取得するか、認証情報から取得）
	projectID := baseCredentials.ProjectID
	if projectID == "" {
		projectID = os.Getenv("GOOGLE_CLOUD_PROJECT")
		if projectID == "" {
			projectID = os.Getenv("GCP_PROJECT")
			if projectID == "" {
				log.Fatal("プロジェクトIDが取得できません。GOOGLE_CLOUD_PROJECTまたはGCP_PROJECT環境変数を設定してください")
			}
		}
	}

	// サービスアカウントのimpersonation設定
	targetServiceAccount := "spreadsheet-service-account@" + projectID + ".iam.gserviceaccount.com"

	impersonatedCredentials, err := impersonate.CredentialsTokenSource(ctx, impersonate.CredentialsConfig{
		TargetPrincipal: targetServiceAccount,
		Scopes:          []string{sheets.SpreadsheetsScope},
	}, option.WithCredentials(baseCredentials))
	if err != nil {
		log.Fatalf("impersonation認証の設定に失敗しました: %v", err)
	}

	// 認証されたユーザー情報を表示
	fmt.Printf("認証方法: Impersonation\n")
	fmt.Printf("ベースアカウント: gosukenator@gmail.com\n")
	fmt.Printf("Impersonateするサービスアカウント: %s\n", targetServiceAccount)
	fmt.Printf("プロジェクトID: %s\n", projectID)
	fmt.Println()
	
	// Impersonationが成功したかテスト
	fmt.Println("Impersonation認証をテスト中...")

	// Google Sheets APIサービスを作成
	srv, err := sheets.NewService(ctx, option.WithTokenSource(impersonatedCredentials))
	if err != nil {
		log.Fatalf("Sheets APIサービスの作成に失敗しました: %v", err)
	}

	// スプレッドシートIDを環境変数から取得
	spreadsheetID := os.Getenv("SPREADSHEET_ID")
	if spreadsheetID == "" {
		log.Fatal("環境変数SPREADSHEET_IDが設定されていません")
	}

	// スプレッドシートの情報を取得
	fmt.Printf("スプレッドシートID: %s にアクセス中...\n", spreadsheetID)
	spreadsheet, err := srv.Spreadsheets.Get(spreadsheetID).Do()
	if err != nil {
		fmt.Printf("エラーの詳細: %v\n", err)
		fmt.Println("\n考えられる原因:")
		fmt.Println("1. gosukenator@gmail.com が Service Account Token Creator ロールを持っていない")
		fmt.Printf("   → gcloud projects add-iam-policy-binding %s \\\n", projectID)
		fmt.Printf("       --member=\"user:gosukenator@gmail.com\" \\\n")
		fmt.Printf("       --role=\"roles/iam.serviceAccountTokenCreator\"\n\n")
		fmt.Printf("2. %s がスプレッドシートへのアクセス権限を持っていない\n", targetServiceAccount)
		fmt.Println("   → スプレッドシートを上記サービスアカウントと共有してください")
		fmt.Printf("3. %s が存在しない\n", targetServiceAccount)
		fmt.Println("   → サービスアカウントを作成してください")
		log.Fatalf("スプレッドシートの取得に失敗しました: %v", err)
	}

	fmt.Printf("スプレッドシート名: %s\n", spreadsheet.Properties.Title)
	fmt.Printf("シート数: %d\n", len(spreadsheet.Sheets))

	// 最初のシートからデータを読み取り
	if len(spreadsheet.Sheets) > 0 {
		sheetName := spreadsheet.Sheets[0].Properties.Title
		readRange := fmt.Sprintf("%s!A1:E10", sheetName)

		resp, err := srv.Spreadsheets.Values.Get(spreadsheetID, readRange).Do()
		if err != nil {
			log.Fatalf("データの読み取りに失敗しました: %v", err)
		}

		fmt.Printf("\n%s からデータを読み取り:\n", readRange)
		if len(resp.Values) == 0 {
			fmt.Println("データが見つかりませんでした。")
		} else {
			for i, row := range resp.Values {
				fmt.Printf("行 %d: %v\n", i+1, row)
			}
		}

		// サンプルデータを書き込み
		writeRange := fmt.Sprintf("%s!A12:C12", sheetName)
		values := [][]interface{}{
			{"Go プログラム", "からの書き込み", fmt.Sprintf("実行時刻: %s", ctx.Value("timestamp"))},
		}

		valueRange := &sheets.ValueRange{
			Values: values,
		}

		_, err = srv.Spreadsheets.Values.Update(spreadsheetID, writeRange, valueRange).
			ValueInputOption("RAW").Do()
		if err != nil {
			log.Printf("データの書き込みに失敗しました: %v", err)
		} else {
			fmt.Printf("\n%s にデータを書き込みました\n", writeRange)
		}
	}
}
