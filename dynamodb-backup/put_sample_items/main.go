package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// randomString generates a random alphanumeric string of given length.
func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	s := make([]byte, n)
	for i := range s {
		s[i] = letters[rand.Intn(len(letters))]
	}
	return string(s)
}

func main() {
	// ランダムシードの初期化
	rand.Seed(time.Now().UnixNano())

	// AWS SDK for Go v2 の設定読み込み（リージョンは適宜変更）
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion("ap-northeast-1"))
	if err != nil {
		log.Fatalf("設定の読み込みに失敗しました: %v", err)
	}

	// DynamoDB クライアントの作成
	svc := dynamodb.NewFromConfig(cfg)
	tableName := "User"
	batchSize := 25
	totalItems := 100000

	var writeRequests []types.WriteRequest

	ctx := context.Background()

	// 10万件のデータを生成し、バッチ書き込みするループ
	for i := 0; i < totalItems; i++ {
		// 一意な username を生成（例: user_000001）
		username := fmt.Sprintf("user_%06d", i)

		// ランダムなパスワードを生成し、bcrypt でハッシュ化
		plainPassword := randomString(12)
		hashed, err := bcrypt.GenerateFromPassword([]byte(plainPassword), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("パスワードハッシュ生成エラー: %v", err)
		}
		hashedStr := string(hashed)

		// UUID を生成し、UserId にセット
		userId := uuid.New().String()

		// DynamoDB に登録するアイテム
		item := map[string]types.AttributeValue{
			"UserName": &types.AttributeValueMemberS{Value: username},
			"PasswordHash": &types.AttributeValueMemberS{
				Value: hashedStr,
			},
			"UserId": &types.AttributeValueMemberS{
				Value: userId,
			},
		}

		// WriteRequest を作成してスライスに追加
		writeReq := types.WriteRequest{
			PutRequest: &types.PutRequest{
				Item: item,
			},
		}
		writeRequests = append(writeRequests, writeReq)

		// バッチサイズに達した場合、または最終アイテムの場合にバッチ書き込みを実行
		if len(writeRequests) == batchSize || i == totalItems-1 {
			input := &dynamodb.BatchWriteItemInput{
				RequestItems: map[string][]types.WriteRequest{
					tableName: writeRequests,
				},
			}

			_, err := svc.BatchWriteItem(ctx, input)
			if err != nil {
				log.Fatalf("バッチ書き込みに失敗しました: %v", err)
			}

			// スライスをリセット
			writeRequests = writeRequests[:0]
		}
	}

	fmt.Println("10万件のデータ登録が完了しました。")
}
