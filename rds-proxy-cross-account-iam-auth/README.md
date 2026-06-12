# RDS ProxyへのクロスアカウントIAM認証検証

RDS Proxyに対して別アカウントのクライアントからIAM認証で接続できるかを検証するための環境。

## アーキテクチャ

```
+----------------------------------------+     +----------------------------------------+
| RDSアカウント (000767026184)            |     | クライアントアカウント (914357407416)     |
|                                        |     |                                        |
|  VPC 10.0.0.0/16                       |     |  VPC 10.1.0.0/16                       |
|  +----------------------------------+  |     |  +----------------------------------+  |
|  | プライベートサブネット x2          |  |     |  | パブリックサブネット              |  |
|  |                                  |  |     |  |  NAT Gateway                     |  |
|  |  RDS PostgreSQL (パスワード認証)  |  |     |  +----------------------------------+  |
|  |   ↑ Secrets Managerの認証情報     |  |     |  +----------------------------------+  |
|  |  RDS Proxy (IAM認証 REQUIRED)    |<=============| プライベートサブネット            |  |
|  +----------------------------------+  | VPC |  |  CloudShell VPC環境 (検証用)      |  |
|                                        |Peering|  EC2 (Amazon Linux 2023, 参考用)   |  |
|  IAMロール: db-connect                  |     |  +----------------------------------+  |
|   (rds-db:connect権限、               |     |  IAMロール: client                      |
|    クライアントアカウントから           |     |   (rds-db:connect直接付与 +             |
|    AssumeRole可)                       |     |    db-connectロールへのAssumeRole権限)  |
+----------------------------------------+     +----------------------------------------+
```

- RDSインスタンスのマスターユーザー(dbadmin)はパスワード認証。パスワードは `manage_master_user_password` によりSecrets Managerで管理
- RDSインスタンスは `iam_database_authentication_enabled = true` でIAM DB認証も有効化済み。直接IAM認証の検証用に `rds_iam` ロールを付与した `iam_user` を別途作成してある(dbadminに `rds_iam` を付与するとパスワード認証が拒否されるようになり、Proxy → RDS間の接続が壊れるため別ユーザーとしている)
- 現在のコードは**end-to-end IAM認証**構成(`default_auth_scheme = "IAM_AUTH"`)。クライアント → Proxy間もProxy → RDS間もIAM認証で、ProxyへのSecrets Managerシークレット登録は不要。Proxy経由で接続できるのは `rds_iam` を付与したユーザー(iam_user)のみで、dbadminはProxy経由では接続できない
- 切り替え前の標準IAM認証構成(クライアント → Proxy間のみIAM認証 `iam_auth = "REQUIRED"`、Proxy → RDS間はSecrets Managerのパスワード)でも検証済み(検証結果参照)
- 検証パターンは2つ
  1. **直接パターン**: クライアントアカウントのIAMロールに `rds-db:connect` を直接付与してトークンを生成
  2. **AssumeRoleパターン**: RDSアカウント側の `db-connect` ロールにAssumeRoleしてからトークンを生成

## ディレクトリ構成

```
rds-proxy-cross-account-iam-auth/
├── rds-account/      RDSアカウント (000767026184) 用 / aws-vault profile: rds-proxy
└── client-account/   クライアントアカウント (914357407416) 用 / aws-vault profile: rds-client
```

VPC Peeringの接続情報やProxyのリソースIDがアカウント間で相互参照になるため、以下の順序でステップバイステップに適用する。

## 構築手順

### Step 1: クライアントアカウントのベース環境を構築

クライアント側のVPC(パブリックサブネット + NAT Gateway + プライベートサブネット)、EC2インスタンス、IAMロールを作成する。検証に使うCloudShell VPC環境とEC2はプライベートサブネットに配置し、アウトバウンド通信はNAT Gateway経由とする。この時点ではPeering関連の変数は未設定のままでよい。

#### 実行コマンド

```bash
START_TIME=$(date +%s)
echo "クライアントアカウントのベース環境を構築中"
cd client-account
aws-vault exec rds-client -- terraform init
aws-vault exec rds-client -- terraform apply
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

#### 期待される出力例

```
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

client_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
ec2_role_arn = "arn:aws:iam::914357407416:role/cross-account-iam-auth-client"
instance_id = "i-xxxxxxxxxxxxxxxxx"
private_subnet_id = "subnet-xxxxxxxxxxxxxxxxx"
vpc_cidr = "10.1.0.0/16"
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
```

#### 確認項目

- [ ] applyがエラーなく完了している
- [ ] `vpc_id` が出力されている(Step 2で使用)
- [ ] `private_subnet_id` と `client_security_group_id` が出力されている(Step 5のCloudShell VPC環境作成で使用)

### Step 2: RDSアカウントの環境を構築

RDS、RDS Proxy、VPC Peering(リクエスト側)、クロスアカウント接続用IAMロールを作成する。Step 1の出力を `terraform.tfvars` に設定してから適用する。RDSインスタンスの作成に10分前後かかる。

#### 実行コマンド

```bash
cd ../rds-account
cat <<TFVARS > terraform.tfvars
client_vpc_id    = "vpc-xxxxxxxxxxxxxxxxx"
peering_accepted = false
TFVARS
START_TIME=$(date +%s)
echo "RDSアカウントの環境を構築中"
aws-vault exec rds-proxy -- terraform init
aws-vault exec rds-proxy -- terraform apply
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

#### 期待される出力例

```
Apply complete! Resources: 21 added, 0 changed, 0 destroyed.

Outputs:

db_connect_role_arn = "arn:aws:iam::000767026184:role/cross-account-iam-auth-db-connect"
db_user_arn = "arn:aws:rds-db:ap-northeast-1:000767026184:dbuser:prx-xxxxxxxxxxxxxxxxx/dbadmin"
db_username = "dbadmin"
peering_connection_id = "pcx-xxxxxxxxxxxxxxxxx"
rds_proxy_endpoint = "cross-account-iam-auth.proxy-xxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com"
rds_proxy_resource_id = "prx-xxxxxxxxxxxxxxxxx"
vpc_cidr = "10.0.0.0/16"
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
```

#### 確認項目

- [ ] applyがエラーなく完了している
- [ ] `peering_connection_id`、`rds_proxy_resource_id`、`db_connect_role_arn` が出力されている(Step 3で使用)
- [ ] `rds_proxy_endpoint` が出力されている(Step 5の接続検証で使用)

### Step 3: クライアントアカウントでPeering承認とIAMポリシー追加

VPC Peeringの承認、RDSアカウントVPCへのルート追加、`rds-db:connect` と `sts:AssumeRole` のIAMポリシーを追加する。Step 2の出力を `terraform.tfvars` に設定してから適用する。

#### 実行コマンド

```bash
cd ../client-account
cat <<TFVARS > terraform.tfvars
peering_connection_id = "pcx-xxxxxxxxxxxxxxxxx"
rds_proxy_resource_id = "prx-xxxxxxxxxxxxxxxxx"
db_connect_role_arn   = "arn:aws:iam::000767026184:role/cross-account-iam-auth-db-connect"
TFVARS
START_TIME=$(date +%s)
echo "Peering承認とIAMポリシーを追加中"
aws-vault exec rds-client -- terraform apply
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

#### 期待される出力例

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

#### 確認項目

- [ ] applyがエラーなく完了している
- [ ] `aws_vpc_peering_connection_accepter.from_rds[0]` が作成されている

### Step 4: RDSアカウントでPeering向けルートを追加

Peeringが承認済みになったので、RDSアカウント側のルートテーブルにクライアントVPC向けのルートを追加する。

#### 実行コマンド

```bash
cd ../rds-account
sed -i '' 's/peering_accepted    = false/peering_accepted    = true/' terraform.tfvars
START_TIME=$(date +%s)
echo "クライアントVPC向けルートを追加中"
aws-vault exec rds-proxy -- terraform apply
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"
```

#### 期待される出力例

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

#### 確認項目

- [ ] applyがエラーなく完了している
- [ ] `aws_route.to_client[0]` が作成されている

### Step 5: IAM認証での接続検証(CloudShell)

**注意**: 以下の手順はProxyが標準IAM認証構成(`auth_scheme = SECRETS`)だった時点のもの。現在のコードはend-to-end IAM認証構成(Step 7参照)のため、Proxy経由で接続できるのは `iam_user` のみで、手順中の `dbadmin` は `iam_user` に読み替える(`iam_user` の作成はStep 6-1参照)。

クライアントアカウントのCloudShell VPC環境からRDS ProxyにIAM認証で接続する。CloudShellの認証情報はコンソールにログインしているIAMプリンシパルのものになる。`db-connect` ロールの信頼ポリシーはクライアントアカウント全体(`arn:aws:iam::914357407416:root`)を許可しているため、コンソールプリンシパルに `sts:AssumeRole` 権限があれば追加設定なしでAssumeRoleパターンを検証できる。

#### 5-1. CloudShell VPC環境の作成

CloudShell VPC環境の作成に必要な値を手元のターミナルで確認する。

```bash
cd client-account
aws-vault exec rds-client -- terraform output
```

マネジメントコンソールでの操作:

1. クライアントアカウント(914357407416)のコンソールにログインし、CloudShellを開く
2. 環境メニューの「+」から「Create VPC environment」を選択する
3. 以下を指定して作成する
   - Name: 任意(例: `cross-account-iam-auth`)
   - VPC: `vpc_id` の値
   - Subnet: `private_subnet_id` の値(プライベートサブネット)
   - Security group: `client_security_group_id` の値

#### 5-2. 事前確認

CloudShell VPC環境のシェルで、psqlの存在・自分のプリンシパル・ProxyへのTCP疎通を確認する。`PROXY_ENDPOINT` にはrds-accountの `rds_proxy_endpoint` 出力値を設定する。

```bash
PROXY="<rds_proxy_endpointの値>"
CONN="host=$PROXY port=5432 dbname=appdb user=dbadmin sslmode=require"
psql --version
aws sts get-caller-identity --query Arn --output text
timeout 5 bash -c "echo > /dev/tcp/$PROXY/5432" && echo "疎通OK" || echo "疎通NG"
```

psqlが入っていない場合は、プライベートサブネットからNAT Gateway経由でインターネットに出られるため、その場でインストールできる。

```bash
sudo dnf install -y postgresql16
```

#### 期待される出力例

```
psql (PostgreSQL) 16.x
arn:aws:sts::914357407416:assumed-role/<コンソールのロール名>/<セッション名>
疎通OK
```

#### 確認項目

- [ ] psqlが使用できる
- [ ] 呼び出し元がクライアントアカウント(914357407416)のプリンシパルになっている
- [ ] ProxyエンドポイントへのTCP疎通が取れている(疎通NGの場合はPeering、ルートテーブル、セキュリティグループを確認)

#### 5-3. AssumeRoleパターンでの接続(成功するパターン)

RDSアカウント側の `db-connect` ロールにAssumeRoleし、その一時認証情報でトークンを生成して接続する。

```bash
echo "db-connectロールにAssumeRole中"
ROLE_ARN="arn:aws:iam::000767026184:role/cross-account-iam-auth-db-connect"
CREDS=$(aws sts assume-role --role-arn "$ROLE_ARN" \
  --role-session-name iam-auth-test --query Credentials --output json)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)
aws sts get-caller-identity --query Arn --output text
TOKEN=$(aws rds generate-db-auth-token --hostname "$PROXY" \
  --port 5432 --username dbadmin --region ap-northeast-1)
export PGPASSWORD="$TOKEN"
psql "$CONN" -c "SELECT current_user, inet_server_addr();"
```

#### 期待される出力例

```
arn:aws:sts::000767026184:assumed-role/cross-account-iam-auth-db-connect/iam-auth-test
 current_user | inet_server_addr
--------------+------------------
 dbadmin      | 10.0.x.x
(1 row)
```

#### 確認項目

- [ ] 呼び出し元がRDSアカウント(000767026184)の `db-connect` ロールに切り替わっている
- [ ] `current_user = dbadmin` で接続できている
- [ ] `inet_server_addr` がRDSアカウントVPCのプライベートIP(10.0.x.x)になっている

`The IAM authentication failed` で失敗する場合は、`echo "$TOKEN" | head -c 50` でトークンが空でないこと、`aws sts get-caller-identity` で呼び出し元が `db-connect` ロールになっていることを確認する。`TOKEN` や `CREDS` が空のままだとCloudShell本来の認証情報で署名され、同じエラーになる。トークンの有効期限は15分なので、生成後はすぐに接続する。

#### 5-4. (参考)直接パターンでの接続(失敗するパターン)

一時認証情報を解除し、クライアントアカウントのプリンシパルのままトークンを生成して接続を試みる。`rds-db:connect` はリソースベースポリシー非対応のため、クライアントアカウント側でポリシーを付与していても失敗する。

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws sts get-caller-identity --query Arn --output text
TOKEN=$(aws rds generate-db-auth-token --hostname "$PROXY" \
  --port 5432 --username dbadmin --region ap-northeast-1)
export PGPASSWORD="$TOKEN"
psql "$CONN" -c "SELECT current_user;"
```

#### 期待される出力例

```
psql: error: connection to server at "..." failed: FATAL:  The IAM authentication failed for the role dbadmin. Check the IAM token for this role and try again.
```

#### 確認項目

- [ ] クライアントアカウントのプリンシパルによる直接接続が `The IAM authentication failed` で拒否される

### (参考)EC2から検証する場合

CloudShellの代わりに、プライベートサブネット内のEC2インスタンスからも同じ検証ができる。EC2インスタンスロールには `rds-db:connect` の直接付与と `sts:AssumeRole` の両方を付与してあるため、直接パターンの失敗も厳密に再現できる。

```bash
aws-vault exec rds-client -- aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region ap-northeast-1
```

セッション内の手順は5-3、5-4と同じ。EC2にはjqが入っていないため、認証情報の取り出しには `python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'])"` のようにpython3を使うか、`sudo dnf install -y jq` でjqをインストールする。

### Step 6: RDSインスタンスへの直接IAM認証の検証

RDS Proxyを経由せず、RDSインスタンスに直接IAM認証で接続するパターンも検証できる。RDSインスタンスの `iam_database_authentication_enabled = true` と、RDS用セキュリティグループへのクライアントVPC CIDR許可は設定済み。

#### 6-1. IAM認証用DBユーザーの作成(初回のみ)

`rds_iam` ロールを付与したDBユーザーを作成する。Step 5-3(AssumeRole + Proxy経由でdbadmin接続)の状態から続けて実行する。

```bash
psql "$CONN" -c "CREATE USER iam_user WITH LOGIN;"
psql "$CONN" -c "GRANT rds_iam TO iam_user;"
```

end-to-end IAM認証構成ではProxy経由のdbadmin接続ができないため、マスターパスワードをSecrets Managerから取得し、RDSインスタンスに直接接続して実行する。

```bash
SECRET_ARN=$(aws-vault exec rds-proxy -- aws rds describe-db-instances \
  --db-instance-identifier cross-account-iam-auth \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
aws-vault exec rds-proxy -- aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" --query SecretString --output text
```

#### 6-2. RDSインスタンスへ直接IAM認証で接続

`RDS` にはrds-accountの `rds_endpoint` 出力値を設定する。AssumeRoleした状態のまま実行する。

```bash
RDS="<rds_endpointの値>"
RCONN="host=$RDS port=5432 dbname=appdb user=iam_user sslmode=require"
TOKEN=$(aws rds generate-db-auth-token --hostname "$RDS" \
  --port 5432 --username iam_user --region ap-northeast-1)
export PGPASSWORD="$TOKEN"
psql "$RCONN" -c "SELECT current_user, inet_server_addr();"
```

#### 期待される出力例

AssumeRoleした状態(成功するパターン):

```
 current_user | inet_server_addr
--------------+------------------
 iam_user     | 10.0.x.x
(1 row)
```

クライアントアカウントのプリンシパルのまま(失敗するパターン):

```
FATAL:  PAM authentication failed for user "iam_user"
```

#### 確認項目

- [ ] AssumeRole状態で `current_user = iam_user` で接続できる
- [ ] クライアントアカウントのプリンシパルのままでは `PAM authentication failed` で拒否される

### Step 7: end-to-end IAM認証への切り替えと検証

2025年9月リリースの[end-to-end IAM認証](https://aws.amazon.com/about-aws/whats-new/2025/09/amazon-rds-proxy-end-to-end-iam-authentication/)により、Proxy → RDS間もIAM認証にできる(ProxyへのSecrets Managerシークレット登録が不要になる)。現在のコードはこの構成になっている。

標準IAM認証構成からの変更点:

- `aws_db_proxy` に `default_auth_scheme = "IAM_AUTH"` を設定し、`auth` ブロック(Secrets Manager参照)を削除
- ProxyのIAMロールの権限を `secretsmanager:GetSecretValue` + `kms:Decrypt` から、RDSインスタンスへの `rds-db:connect`(iam_user)に変更
- `db-connect` ロールにProxyの `iam_user` 用dbuser ARNを追加
- 接続先のDBユーザーは `rds_iam` を付与済みであること(Proxy → RDS間の接続もIAM認証になるため)

#### 実行コマンド(AssumeRole後に実行)

```bash
TOKEN=$(aws rds generate-db-auth-token --hostname "$PROXY" \
  --port 5432 --username iam_user --region ap-northeast-1)
export PGPASSWORD="$TOKEN"
psql "host=$PROXY port=5432 dbname=appdb user=iam_user sslmode=require" \
  -c "SELECT current_user, inet_server_addr();"
```

#### 確認項目

- [ ] AssumeRole状態で `current_user = iam_user` で接続できる
- [ ] `rds_iam` のないユーザー(dbadmin)では `FATAL: This RDS proxy has no credentials for the role dbadmin` で拒否される

切り替え直後は、標準IAM認証時代に確立されたプール内のバックエンド接続が再利用され、dbadminでも接続できてしまうことがある。プールの接続が切れた後(インスタンス再起動後など)は上記のエラーで一貫して拒否される。

## 検証結果(2026-06-12実施)

**結論: 別アカウントのクライアントからRDS ProxyへのIAM認証接続は達成できた。** 方法は「Proxyと同一アカウントのIAMロールにAssumeRoleしてから認証トークンを生成する」で、標準IAM認証構成・end-to-end IAM認証構成のどちらでも成功した(パターン2、5)。RDSインスタンスへの直接IAM認証も同様に成功した(パターン4)。

以下の表で「接続失敗」となっているパターンは、制約を確認するために意図的に実行したテストで、すべて期待どおりの結果(検証としては全パターン成功)。

標準IAM認証構成(クライアント → Proxy間のみIAM認証):

| パターン | 種別 | 接続 | 出力 |
|---------|------|------|------|
| 1. Proxy × クライアントアカウントのロールのまま | 制約の確認 | 失敗(期待どおり) | `FATAL: The IAM authentication failed for the role dbadmin. Check the IAM token for this role and try again.` |
| 2. Proxy × AssumeRole | **目的の検証** | **成功** | `current_user = dbadmin` で接続でき、`inet_server_addr = 10.0.1.145`(Proxy経由のRDS接続)が返った |
| 3. RDSインスタンス直接 × クライアントアカウントのロールのまま | 制約の確認 | 失敗(期待どおり) | `FATAL: PAM authentication failed for user "iam_user"` |
| 4. RDSインスタンス直接 × AssumeRole | **目的の検証** | **成功** | `current_user = iam_user` で接続できた |

end-to-end IAM認証構成(Proxy → RDS間もIAM認証、シークレット登録なし):

| パターン | 種別 | 接続 | 出力 |
|---------|------|------|------|
| 5. Proxy経由 iam_user × AssumeRole | **目的の検証** | **成功** | `current_user = iam_user` で接続できた(シークレット登録ゼロ) |
| 6. Proxy経由 dbadmin(`rds_iam` なし) × AssumeRole | 制約の確認 | 失敗(期待どおり) | `FATAL: This RDS proxy has no credentials for the role dbadmin` |
| 7. Proxy経由 iam_user × クライアントアカウントのロールのまま | 制約の確認 | 失敗(期待どおり) | `FATAL: The IAM authentication failed for the role iam_user`(クロスアカウント直接はe2eでも不可) |

RDS Proxy経由・RDSインスタンス直接のどちらでも結論は同じで、`rds-db:connect` の権限評価はトークンに署名したプリンシパルの所属アカウントで行われるため、クロスアカウントの直接IAM認証は通らない。エラーメッセージはProxyが `The IAM authentication failed for the role ...`、RDSインスタンスが `PAM authentication failed for user "..."` と異なる。

`rds-db:connect` はリソースベースポリシーをサポートしないため、別アカウントのプリンシパルが署名したトークンは(自アカウントのIAMポリシーで対象ARNを許可していても)Proxy側で認証されない。クロスアカウントでRDS ProxyにIAM認証する場合は、**Proxyと同一アカウントのIAMロールへAssumeRoleしてからトークンを生成する**必要がある。

ネットワーク面では、ProxyエンドポイントのDNS名はクライアントVPCからでもRDSアカウントVPCのプライベートIPに解決され、VPC Peering経由でそのまま到達できる(Route 53等の追加設定は不要)。クライアント側をプライベートサブネット(アウトバウンドはNAT Gateway経由)に変更した構成でも、同一の結果を再確認済み。

## 環境の削除

課金リソース(RDS、RDS Proxy、EC2)があるため、検証後は削除する。Peeringの依存関係があるため、クライアントアカウント側から削除する。

#### 実行コマンド

```bash
cd client-account
echo "クライアントアカウントのリソースを削除中"
aws-vault exec rds-client -- terraform destroy
cd ../rds-account
echo "RDSアカウントのリソースを削除中"
aws-vault exec rds-proxy -- terraform destroy
```

#### 確認項目

- [ ] 両アカウントで `Destroy complete!` が出力されている
