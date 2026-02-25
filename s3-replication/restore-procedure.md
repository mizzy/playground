# S3 レプリケーション先バケットからのリストア手順

レプリケーション先バケット（GLACIER / DEEP_ARCHIVE）からソースバケットへ、prefix単位でオブジェクトをリストアする手順。

## 前提条件

- AWS CLIがインストール済み
- `aws-vault` でAWS認証情報にアクセス可能
- レプリケーション先バケット: `s3-replication-test-destination-019115212452`
- リストア先（ソース）バケット: `s3-replication-test-source-019115212452`

## 手順

### 1. バケット名・PREFIXの設定

```bash
SOURCE_BUCKET="s3-replication-test-source-019115212452"
DEST_BUCKET="s3-replication-test-destination-019115212452"
PREFIX="your/prefix/"
```

`PREFIX` はリストア対象のprefix（例: `logs/2026/01/`）。このprefix配下の全オブジェクトがリストア対象になる。

### 2. 対象オブジェクトの確認

対象prefixのオブジェクト一覧とストレージクラスを確認する。

```bash
aws-vault exec mizzy -- aws s3api list-objects-v2 \
  --bucket "$DEST_BUCKET" \
  --prefix "$PREFIX" \
  --query "Contents[].{Key:Key,Size:Size,StorageClass:StorageClass}" \
  --output table
```

#### 期待される出力例

```
-----------------------------------------------------
|                   ListObjectsV2                   |
+--------------------------+-------+----------------+
|            Key           | Size  | StorageClass   |
+--------------------------+-------+----------------+
|  restore-test/file1.txt  |  15   |  GLACIER       |
|  restore-test/file2.txt  |  15   |  GLACIER       |
+--------------------------+-------+----------------+
```

オブジェクト数とストレージクラスの内訳を確認する。

```bash
aws-vault exec mizzy -- aws s3api list-objects-v2 \
  --bucket "$DEST_BUCKET" \
  --prefix "$PREFIX" \
  --query "Contents[].StorageClass" \
  --output text | tr '\t' '\n' | sort | uniq -c
```

#### 期待される出力例

GLACIERの場合:

```
   2 GLACIER
```

DEEP_ARCHIVEの場合:

```
   2 DEEP_ARCHIVE
```

混在している場合:

```
   3 DEEP_ARCHIVE
   5 GLACIER
```

ここで確認したストレージクラスを元に、手順3でTIERを選択する。混在している場合はDEEP_ARCHIVEに合わせてTIERを選択すること（`Expedited` は使用不可）。

#### 確認項目

- [ ] 対象オブジェクトが存在すること
- [ ] ストレージクラスがGLACIERとDEEP_ARCHIVEのどちらであるか確認したこと

### 3. RESTORE_DAYS・TIERの設定

手順2で確認したストレージクラスを元に、`RESTORE_DAYS` と `TIER` を設定する。

```bash
RESTORE_DAYS=7
TIER="Standard"
```

#### RESTORE_DAYS（一時アクセス可能日数）

GLACIER / DEEP_ARCHIVE のオブジェクトは通常直接アクセスできない。リストアリクエストを発行すると、**一時的なコピー**がSTANDARDストレージに作成され、`RESTORE_DAYS` で指定した日数の間だけアクセス可能になる。期限が過ぎると一時コピーは自動削除され、再びアクセス不可に戻る（元のGLACIER / DEEP_ARCHIVEのオブジェクト自体は変更されない）。

本手順では、一時コピーが作成されてから `RESTORE_DAYS` 以内にソースバケットへのコピー（手順6）を完了する必要がある。期限を過ぎると一時コピーが削除され、再度リストアリクエストからやり直しになる。

| 状況 | 推奨値 | 備考 |
|---|---|---|
| 少量のオブジェクト、すぐコピーする | 1〜3日 | コスト最小 |
| 大量データ、コピーに時間がかかる | 7〜14日 | |
| 作業スケジュールに余裕を持たせたい | 14〜30日 | |

日数が長いほど一時コピーの保持にSTANDARDストレージ料金がかかるため、必要最小限に設定するのがコスト面では望ましい。

#### TIER（取り出し速度）

`TIER` はリストアの取り出し速度を指定する。以下の3つから選択する。速いほどコストが高い。

| TIER値 | 対象のストレージクラスがGLACIERの場合 | 対象のストレージクラスがDEEP_ARCHIVEの場合 |
|---|---|---|
| `Expedited` | 1〜5分 | **利用不可** |
| `Standard` | 3〜5時間 | 12時間 |
| `Bulk` | 5〜12時間 | 48時間 |

**TIER選択の判断基準:**

| 状況 | 推奨TIER |
|---|---|
| 緊急時の少量データ取り出し（GLACIERのみ） | `Expedited` |
| 通常のリストア作業 | `Standard` |
| 大量データの低コスト取り出し | `Bulk` |
| GLACIERとDEEP_ARCHIVEが混在 | `Standard` または `Bulk` |

DEEP_ARCHIVEのオブジェクトが含まれる場合は `Expedited` を指定するとエラーになるため、`Standard` または `Bulk` を使用すること。

### 4. リストアリクエストの発行

prefix配下の全オブジェクトに対してリストアリクエストを発行する。

```bash
aws-vault exec mizzy -- aws s3api list-objects-v2 \
  --bucket "$DEST_BUCKET" \
  --prefix "$PREFIX" \
  --query "Contents[].Key" \
  --output text | tr '\t' '\n' | while read -r key; do
  echo "リストアリクエスト発行: $key"
  aws-vault exec mizzy -- aws s3api restore-object \
    --bucket "$DEST_BUCKET" \
    --key "$key" \
    --restore-request "{\"Days\":${RESTORE_DAYS},\"GlacierJobParameters\":{\"Tier\":\"${TIER}\"}}"
done
```

#### 期待される出力例

```
リストアリクエスト発行: restore-test/file1.txt
リストアリクエスト発行: restore-test/file2.txt
```

既にリストアリクエスト済みのオブジェクトがある場合は `RestoreAlreadyInProgress` エラーが返るが、問題ない。

### 5. リストアステータスの確認

リストアが完了するまで待つ。完了すると `ongoing-request="false"` になる。

```bash
aws-vault exec mizzy -- aws s3api list-objects-v2 \
  --bucket "$DEST_BUCKET" \
  --prefix "$PREFIX" \
  --query "Contents[].Key" \
  --output text | tr '\t' '\n' | while read -r key; do
  restore_status=$(aws-vault exec mizzy -- aws s3api head-object \
    --bucket "$DEST_BUCKET" \
    --key "$key" \
    --query "Restore" \
    --output text 2>/dev/null)
  echo "$key: $restore_status"
done
```

#### 期待される出力例（リストア処理中）

```
restore-test/file1.txt: ongoing-request="true"
restore-test/file2.txt: ongoing-request="true"
```

#### 期待される出力例（リストア完了）

```
restore-test/file1.txt: ongoing-request="false", expiry-date="Thu, 05 Mar 2026 00:00:00 GMT"
restore-test/file2.txt: ongoing-request="false", expiry-date="Thu, 05 Mar 2026 00:00:00 GMT"
```

#### ステータスの読み方

| ステータス | 意味 |
|---|---|
| `ongoing-request="true"` | リストア処理中 |
| `ongoing-request="false", expiry-date="..."` | リストア完了。expiry-dateまでアクセス可能 |
| `None` | リストアリクエスト未発行 |

#### 確認項目

- [ ] 全オブジェクトが `ongoing-request="false"` になっていること

### 6. ソースバケットへのコピー

リストア完了後、オブジェクトをソースバケットにコピーする。

> [!NOTE]
> ソースバケットにコピーされたオブジェクトは新規のPUTとして扱われるため、レプリケーション設定に従って再びレプリケーション先バケットにGLACIERクラスでコピーされる。レプリケーション先バケットはバージョニングが有効なため、再レプリケーションされたオブジェクトは新しいバージョンとして追加され、元のGLACIER/DEEP_ARCHIVEのバージョンもそのまま残る。バックアップの観点では問題ないが、バージョンが増える分ストレージコストが発生する点に留意すること。

```bash
aws-vault exec mizzy -- aws s3 cp \
  "s3://${DEST_BUCKET}/${PREFIX}" \
  "s3://${SOURCE_BUCKET}/${PREFIX}" \
  --recursive \
  --force-glacier-transfer
```

#### 期待される出力例

```
copy: s3://s3-replication-test-destination-019115212452/restore-test/file1.txt to s3://s3-replication-test-source-019115212452/restore-test/file1.txt
copy: s3://s3-replication-test-destination-019115212452/restore-test/file2.txt to s3://s3-replication-test-source-019115212452/restore-test/file2.txt
```

`--force-glacier-transfer` はGLACIER/DEEP_ARCHIVEストレージクラスのオブジェクトのコピーを許可するフラグ。リストア済みであってもストレージクラスの表記はGLACIER/DEEP_ARCHIVEのままであるため、このフラグがないとスキップされる。

#### 確認項目

- [ ] コピー完了のメッセージが表示されること
- [ ] エラーが発生していないこと

### 7. コピー結果の確認

ソースバケットにオブジェクトが存在することを確認する。

```bash
aws-vault exec mizzy -- aws s3api list-objects-v2 \
  --bucket "$SOURCE_BUCKET" \
  --prefix "$PREFIX" \
  --query "Contents[].{Key:Key,Size:Size,StorageClass:StorageClass}" \
  --output table
```

#### 期待される出力例

```
-----------------------------------------------------
|                   ListObjectsV2                   |
+--------------------------+-------+----------------+
|            Key           | Size  | StorageClass   |
+--------------------------+-------+----------------+
|  restore-test/file1.txt  |  15   |  STANDARD      |
|  restore-test/file2.txt  |  15   |  STANDARD      |
+--------------------------+-------+----------------+
```

#### 確認項目

- [ ] 手順2で確認したオブジェクトがすべてソースバケットに存在すること
- [ ] ファイルサイズがレプリケーション先と一致すること

## 注意事項

- GLACIER / DEEP_ARCHIVEからのリストアには時間がかかるため、余裕を持ったスケジュールで実施すること
- DEEP_ARCHIVEのStandardリストアは12時間、Bulkは48時間かかる
- `RESTORE_DAYS` の期間内にコピーを完了すること。期間が過ぎるとオブジェクトは再びアクセス不可になる
