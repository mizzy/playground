#!/bin/bash

ORIGINAL_TABLE="test"
TARGET_TABLE_1="${ORIGINAL_TABLE}-$(date +%Y%m%d%H%M%S)-1"
TARGET_TABLE_2="${ORIGINAL_TABLE}-$(date +%Y%m%d%H%M%S)-2"

# テーブル作成完了チェック用関数
function wait_for_table_creation() {
  local table_name=$1

  echo "Check the status of \"$table_name\"."

  while true; do
    ddb_table_status=$(
      aws dynamodb describe-table --table-name "$table_name" |
        jq -r .Table.TableStatus
    )

    if [ "$ddb_table_status" = "ACTIVE" ]; then
      echo "Restoring \"$table_name\" has been completed."
      break
    else
      echo "Current status: $ddb_table_status"
      sleep 60
    fi
  done
}

start_time=$(date +%s)

# 別名でリストア
aws dynamodb restore-table-to-point-in-time \
  --source-table-name "$ORIGINAL_TABLE" \
  --target-table-name "$TARGET_TABLE_1" \
  --use-latest-restorable-time >/dev/null

wait_for_table_creation "$TARGET_TABLE_1"

# 1回目のリストアにかかった時間を表示
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Time taken to restore ${TARGET_TABLE_1}: $(date -u -d "@$elapsed_time" +%H:%M:%S)"
echo

start_time=$(date +%s)

# 別名でリストアしたテーブルでPITRを有効にする
aws dynamodb update-continuous-backups \
  --table-name "$TARGET_TABLE_1" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true > /dev/null

# 別名テーブルから元の名前でリストアすることを想定した処理
# （このスクリプトはリストア時間計測用なので、実際は別の名前でリストア）
aws dynamodb restore-table-to-point-in-time \
  --source-table-name "$TARGET_TABLE_1" \
  --target-table-name "$TARGET_TABLE_2" \
  --use-latest-restorable-time >/dev/null

wait_for_table_creation "$TARGET_TABLE_2"

# 2回目のリストアにかかった時間を表示
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Time taken to restore ${TARGET_TABLE_2}: $(date -u -d "@$elapsed_time" +%H:%M:%S)"

# リストアしたテーブルは不要なので削除
aws dynamodb delete-table --table-name "$TARGET_TABLE_1" >/dev/null
aws dynamodb delete-table --table-name "$TARGET_TABLE_2" >/dev/null
