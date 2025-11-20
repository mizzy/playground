# Pattern B: Service Network + ServiceNetwork VPC Endpoint を使用したアクセス

## 概要

VPC Lattice Service Network と ServiceNetwork VPC Endpoint を使用してクロスアカウントの RDS/RDS Proxy にアクセスするパターンです。
Pattern A (Resource Endpoint 直接接続) とは異なり、Service Network 経由で複数の Resource Configuration に一元的に接続します。

## ディレクトリ構成

```
cross-account-rds-pattern-b/
├── README.md                      # このファイル
├── rds-proxy/                     # Provider Account
│   ├── aurora_cluster.tf         # Aurora PostgreSQL Cluster
│   ├── rds_proxy.tf              # RDS Proxy
│   ├── resource_gateway.tf       # Resource Gateway
│   ├── rds_proxy_resource_config.tf  # Resource Configurations (RDS Proxy Writer/Reader)
│   ├── ram.tf                    # RAM Resource Share
│   ├── vpc.tf                    # VPC (10.1.0.0/16)
│   ├── provider.tf               # AWS Provider設定
│   ├── outputs.tf                # 出力定義
│   └── secrets.tf                # Secrets Manager
└── rds-client/                    # Consumer Account
    ├── service_network.tf        # Service Network, ServiceNetwork VPC Endpoint, Resource Associations
    ├── database_connectivity.tf  # Security Group
    ├── network.tf                # VPC (10.0.0.0/16)
    ├── ecs_test_infrastructure.tf # ECS Cluster、IAM Roles (テスト用)
    ├── provider.tf               # AWS Provider設定
    ├── variables.tf              # 変数定義
    ├── outputs.tf                # 出力定義
    ├── task-def-rds-proxy-test.json  # ECS Task Definition (テスト用)
    ├── run-test.sh               # テスト実行スクリプト
    └── Makefile                  # Docker image build, ECS tasks (将来追加予定)
```

## アーキテクチャ

```mermaid
graph TB
    subgraph Provider["Provider Account: 000767026184"]
        RG[Resource Gateway<br/>rgw-0c0856f9cf8c56faf]

        subgraph AuroraResources["Aurora Resources"]
            Aurora[("Aurora Cluster<br/>pattern-b-aurora-cluster")]
            AuroraWriter["Writer Endpoint<br/>pattern-b-aurora-cluster.cluster-*.rds.amazonaws.com"]
            AuroraReader["Reader Endpoint<br/>pattern-b-aurora-cluster.cluster-ro-*.rds.amazonaws.com"]
        end

        subgraph ProxyResources["RDS Proxy Resources"]
            Proxy[("RDS Proxy<br/>pattern-b-rds-proxy")]
            ProxyWriter["Writer Endpoint<br/>pattern-b-rds-proxy.proxy-*.rds.amazonaws.com"]
            ProxyReader["Reader Endpoint<br/>pattern-b-rds-proxy-reader.endpoint.proxy-*.rds.amazonaws.com"]
        end

        subgraph ResourceConfigs["Resource Configurations"]
            RC_Aurora["Aurora RC<br/>rcfg-08e1a8d1a3efa6a53<br/>(ARN Type)"]
            RC_Aurora_Writer["Aurora Writer Child RC<br/>rcfg-0163a0e6fcb9eb1f7<br/>(CHILD Type)"]
            RC_Aurora_Reader["Aurora Reader Child RC<br/>rcfg-092a6e19eb1ded941<br/>(CHILD Type)"]
            RC_Proxy_Writer["RDS Proxy Writer RC<br/>rcfg-0824c6814b9373689<br/>(SINGLE Type)"]
            RC_Proxy_Reader["RDS Proxy Reader RC<br/>rcfg-0045a2f984e67c28e<br/>(SINGLE Type)"]
        end

        Aurora --> AuroraWriter
        Aurora --> AuroraReader
        Proxy --> ProxyWriter
        Proxy --> ProxyReader

        RG -.->|ARN-based| RC_Aurora
        RC_Aurora -.->|Auto-generated| RC_Aurora_Writer
        RC_Aurora -.->|Auto-generated| RC_Aurora_Reader
        RG -.->|DNS-based| RC_Proxy_Writer
        RG -.->|DNS-based| RC_Proxy_Reader

        RC_Aurora_Writer -.->|Maps to| AuroraWriter
        RC_Aurora_Reader -.->|Maps to| AuroraReader
        RC_Proxy_Writer -.->|Maps to| ProxyWriter
        RC_Proxy_Reader -.->|Maps to| ProxyReader
    end

    RAM[("RAM Resource Share<br/>Shares Resource Configurations")]
    RC_Aurora -.->|Shared via| RAM
    RC_Proxy_Writer -.->|Shared via| RAM
    RC_Proxy_Reader -.->|Shared via| RAM

    subgraph Consumer["Consumer Account: 914357407416"]
        subgraph VPC["VPC: 10.0.0.0/16"]
            SN["Service Network<br/>sn-0661a3458d26c703c<br/>pattern-b-service-network"]
            SNVPCE["ServiceNetwork VPC Endpoint<br/>vpce-011a293f4ab94273c<br/>private_dns_enabled=true"]

            subgraph Associations["Service Network Resource Associations"]
                SNRA_Aurora["Aurora Association<br/>snra-0f8aaa114bda3641d"]
                SNRA_Writer["RDS Proxy Writer Association<br/>snra-0d19a30c5128a9982"]
                SNRA_Reader["RDS Proxy Reader Association<br/>snra-07b66972b0e51b9ea"]
            end

            ECS["ECS Fargate Tasks<br/>(PostgreSQL Client)"]

            SNVPCE -->|Connects to| SN
            SN --> SNRA_Aurora
            SN --> SNRA_Writer
            SN --> SNRA_Reader

            ECS -->|DNS Query| SNVPCE
        end
    end

    RAM -.->|Accepts| SNRA_Aurora
    RAM -.->|Accepts| SNRA_Writer
    RAM -.->|Accepts| SNRA_Reader

    SNRA_Aurora ==>|VPC Lattice| RG
    SNRA_Writer ==>|VPC Lattice| RG
    SNRA_Reader ==>|VPC Lattice| RG

    style SNVPCE fill:#90EE90,stroke:#333,stroke-width:2px
    style SN fill:#87CEEB,stroke:#333,stroke-width:2px
    style SNRA_Aurora fill:#FFE4B5,stroke:#333,stroke-width:2px
    style SNRA_Writer fill:#FFE4B5,stroke:#333,stroke-width:2px
    style SNRA_Reader fill:#FFE4B5,stroke:#333,stroke-width:2px
    style RG fill:#DDA0DD,stroke:#333,stroke-width:2px
    style Aurora fill:#E6F3FF,stroke:#333,stroke-width:2px
    style Proxy fill:#E6F3FF,stroke:#333,stroke-width:2px
    style ECS fill:#98FB98,stroke:#333,stroke-width:2px
```

## Pattern A との違い

| 項目 | Pattern A | Pattern B |
|------|-----------|-----------|
| **接続方式** | Resource Endpoint 直接接続 | Service Network 経由接続 |
| **VPC Endpoint タイプ** | `Resource` (各 RC ごと) | `ServiceNetwork` (1個のみ) |
| **VPC Endpoint 数** | 3個 (Aurora, RDS Proxy Writer, Reader) | 1個 (ServiceNetwork VPC Endpoint) |
| **Service Network** | 使用しない | 使用する |
| **Resource Association** | 不要 | 必要 (3個) |
| **スケーラビリティ** | RC 追加ごとに VPC Endpoint 追加 | Service Network に Association 追加のみ |
| **管理コスト** | VPC Endpoint を複数管理 | VPC Endpoint 1個 + Association 管理 |
| **柔軟性** | リソースごとに個別設定可能 | Service Network で一元管理 |

## DNS 名前解決の仕組み

Pattern B では、ServiceNetwork VPC Endpoint の `private_dns_enabled = true` により、**ARN-based Resource Configuration (Aurora) のみ** DNS 名前解決が行われます:

### Aurora (ARN-based) の場合

1. **ECS タスクが DNS クエリを発行** (例: `pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com`)
2. **VPC DNS Resolver** (10.0.0.2) が ServiceNetwork VPC Endpoint にクエリを転送
3. **ServiceNetwork VPC Endpoint** が CHILD Resource Configuration の `customDomainName` とマッチング
4. **Service Network Resource Association** を通じて適切な Resource Configuration を特定
5. **VPC Lattice** が Resource Gateway 経由でトラフィックをルーティング
6. **Resource Gateway** が rds-proxy アカウントの実際のAuroraエンドポイントに接続

### Resource Configuration と Custom Domain Name

**Aurora (ARN タイプ + CHILD タイプ):**
- 親 RC (ARN タイプ): Aurora クラスター ARN を指定
- AWS が自動的に CHILD タイプの RC を生成
- CHILD RC には `customDomainName` が自動設定される (例: `pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com`)
- `private_dns_enabled = true` により、Consumer VPC内でAuroraの元のDNS名で接続可能

**RDS Proxy (DNS-based SINGLE タイプ) - ⚠️ Private DNS 非対応:**
- Terraform で `dns_resource.domain_name` のみ指定
- `customDomainName` を設定しても Private DNS は動作しない
- VPC Lattice 自動生成DNS名 (`snra-*.rcfg-*.vpc-lattice-rsc.ap-northeast-1.on.aws`) も Consumer VPC 内で解決されない
- **接続するには VPC Lattice 自動生成DNS名を使用する必要がある** (Private Hosted Zoneでの手動設定も不可)

## 接続性マトリクス

| リソース | 接続方法 | DNS名 | Private DNS対応 | 備考 |
|----------|----------|-------|----------------|------|
| Aurora Cluster (Writer) | Service Network | `pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com` | ✅ **対応** | CHILD RC の customDomainName で自動解決 |
| Aurora Cluster (Reader) | Service Network | `pattern-b-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com` | ✅ **対応** | CHILD RC の customDomainName で自動解決 |
| RDS Proxy Writer | Service Network | VPC Lattice DNS名のみ | ❌ **非対応** | 元のRDS Proxy DNS名では接続不可 |
| RDS Proxy Reader | Service Network | VPC Lattice DNS名のみ | ❌ **非対応** | 元のRDS Proxy DNS名では接続不可 |

### Private DNS 検証結果（2025-11-20）

**Aurora (ARN-based Resource Configuration):**
- ✅ 元のAurora DNS名で接続可能
- ✅ `private_dns_enabled=true` が正常に動作
- ✅ AWS自動生成のCHILD RCによりPrivate DNS対応

**RDS Proxy (DNS-based Resource Configuration):**
- ❌ 元のRDS Proxy DNS名では接続不可（`pattern-b-rds-proxy.proxy-*.rds.amazonaws.com`）
- ❌ `custom_domain_name` を設定してもPrivate DNS非対応
- ❌ VPC Lattice自動生成DNS名（`snra-*.rcfg-*.vpc-lattice-rsc.ap-northeast-1.on.aws`）もConsumer VPC内で解決されない
- ❌ Private Hosted Zoneでの手動CNAME設定も不可（Service Network VPC Endpointが1つのためルーティング情報不足）

**検証内容:**
```bash
# Aurora Writer - 成功
$ psql -h pattern-b-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb
 current_user | inet_server_addr | version
--------------+------------------+--------------------------------------------------------------------------------------------------
 postgres     | 10.1.2.149       | PostgreSQL 15.10 on x86_64-pc-linux-gnu, compiled by x86_64-pc-linux-gnu-gcc (GCC) 9.5.0, 64-bit

# Aurora Reader - 成功
$ psql -h pattern-b-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb
 current_user | inet_server_addr | pg_is_in_recovery
--------------+------------------+-------------------
 postgres     | 10.1.1.184       | t

# RDS Proxy Writer - DNS解決はするが接続タイムアウト
$ getent hosts pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
10.1.1.137      vpce-06bb0d5d04f143cd0-pvlabyto.vpce-svc-0dd2951ed3fa88bfe.ap-northeast-1.vpce.amazonaws.com pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
10.1.2.203      vpce-06bb0d5d04f143cd0-pvlabyto.vpce-svc-0dd2951ed3fa88bfe.ap-northeast-1.vpce.amazonaws.com pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
# 注: 10.1.1.137, 10.1.2.203 = Provider VPCのRDS Proxy VPC Endpoint (vpce-06bb0d5d04f143cd0) のIP
#     Resource Gateway VPC Endpoint (10.1.1.100, 10.1.2.67) とは別物
#     RDS ProxyはResource Gatewayを経由せず、独自のVPC Endpointを使用

$ psql -h pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb
Connection timed out
# Consumer VPC (10.0.0.0/16) からProvider VPC (10.1.0.0/16) のIPには到達不可

# VPC Lattice DNS名の解決テスト - 失敗
$ getent hosts snra-0d19a30c5128a9982.rcfg-0824c6814b9373689.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws
DNS Resolution Failed
```

## デプロイ手順

### 前提条件

- AWS CLI と aws-vault がインストール済み
- Terraform がインストール済み
- Provider Account (000767026184) と Consumer Account (914357407416) の AWS 認証情報が設定済み

### 1. Provider Account のデプロイ

```bash
cd cross-account-rds-pattern-b/rds-proxy
aws-vault exec rds-proxy -- terraform init
aws-vault exec rds-proxy -- terraform plan
aws-vault exec rds-proxy -- terraform apply
```

デプロイ後、以下の出力値をメモします:
- `aurora_resource_config_arn`
- `rds_proxy_writer_resource_config_arn`
- `rds_proxy_reader_resource_config_arn`

### 2. Consumer Account の変数設定

`rds-client/terraform.tfvars` を作成し、Provider Account の出力値を設定します:

```hcl
aurora_resource_config_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-..."
rds_proxy_writer_resource_config_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-..."
rds_proxy_reader_resource_config_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-..."
```

### 3. Consumer Account のデプロイ

```bash
cd cross-account-rds-pattern-b/rds-client
aws-vault exec rds-client -- terraform init
aws-vault exec rds-client -- terraform plan
aws-vault exec rds-client -- terraform apply
```

### 4. 接続テストの実行

#### CloudWatch Logs でテスト結果を確認する方法

```bash
# テストタスクを起動
./run-test.sh

# 別のターミナルで CloudWatch Logs を確認
aws-vault exec rds-client -- aws logs tail /ecs/pattern-b-postgres-test --follow --since 3m
```

## 重要なポイント

### ✅ ServiceNetwork VPC Endpoint の利点

1. **一元管理**: 1つの VPC Endpoint で複数の Resource Configuration に接続
2. **スケーラビリティ**: Resource Configuration を追加する場合、Service Network Resource Association を追加するだけ
3. **コスト最適化**: VPC Endpoint 1個の料金のみ（Pattern A は3個分の料金）
4. **管理の簡素化**: VPC Endpoint の管理対象が減少

### ⚠️ 注意事項

#### Service Network Resource Association の Provider バグ

Terraform AWS Provider には、Service Network Resource Association で ARN と ID の不整合が発生するバグがあります:

**症状**:
```
Provider produced inconsistent result after apply
resource_configuration_identifier: was cty.StringVal("arn:aws:..."), but now cty.StringVal("rcfg-...")
```

**回避策**:
1. リソースを state から削除: `terraform state rm aws_vpclattice_service_network_resource_association.xxx`
2. 既存の Association を import: `terraform import aws_vpclattice_service_network_resource_association.xxx snra-xxx`

#### Private DNS の制限事項

ServiceNetwork VPC Endpoint に `private_dns_enabled = true` を設定した場合の動作：

**✅ ARN-based Resource Configuration (Aurora) の場合:**
- AWS自動生成のCHILD Resource Configurationに`customDomainName`が設定される
- Consumer VPC内で元のAurora DNS名が自動的に解決される
- Pattern Aのように個別のPrivate Hosted Zoneを作成する必要がない

**❌ DNS-based Resource Configuration (RDS Proxy) の場合:**
- `custom_domain_name`を手動設定してもPrivate DNSは動作しない
- Consumer VPC内で元のRDS Proxy DNS名は解決されない
- VPC Lattice自動生成DNS名(`snra-*.rcfg-*.vpc-lattice-rsc.ap-northeast-1.on.aws`)も解決されない
- Private Hosted Zoneでの手動CNAME設定も無効（Service Network VPC Endpointのルーティング制約）
- **Pattern A (Resource VPC Endpoint + Private Hosted Zone) の利用を推奨**

## トラブルシューティング

### Service Network Resource Association が作成できない

**問題**: `ConflictException: Association already exists`

**原因**: 同じ Service Network と Resource Configuration の組み合わせで既に Association が存在する

**解決策**:
```bash
# 既存の Association を確認
aws-vault exec rds-client -- aws vpc-lattice list-service-network-resource-associations \
  --service-network-identifier sn-xxx

# Terraform に import
aws-vault exec rds-client -- terraform import \
  aws_vpclattice_service_network_resource_association.xxx snra-xxx
```

### DNS 名前解決が失敗する

**問題**: `getent hosts` で DNS 解決できない

**確認項目**:
1. ServiceNetwork VPC Endpoint が作成されているか
2. `private_dns_enabled = true` が設定されているか
3. VPC の DNS サポートと DNS ホスト名が有効か
4. Service Network Resource Association が正常に作成されているか

**確認コマンド**:
```bash
# VPC Endpoint 確認
aws-vault exec rds-client -- aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-xxx

# Service Network Resource Association 確認
aws-vault exec rds-client -- aws vpc-lattice list-service-network-resource-associations \
  --service-network-identifier sn-xxx
```

## クリーンアップ

**重要**: 削除は Consumer Account → Provider Account の順番で行います。

### 1. Consumer Account のリソース削除

```bash
cd cross-account-rds-pattern-b/rds-client
aws-vault exec rds-client -- terraform destroy
```

### 2. Provider Account のリソース削除

```bash
cd cross-account-rds-pattern-b/rds-proxy
aws-vault exec rds-proxy -- terraform destroy
```

## 結論と学び

### 検証結果サマリー

1. ✅ **Aurora Cluster (ARN-based Resource Configuration)**: Private DNS完全対応
   - AWS が自動的に CHILD タイプの Resource Configuration を生成
   - `customDomainName` が自動設定される
   - `private_dns_enabled=true` により元のAurora DNS名で接続可能
   - Writer/Reader 両方のエンドポイントが利用可能

2. ✅ **RDS Proxy (DNS-based Resource Configuration)**: カスタムドメイン名機能で対応可能（2025年11月新機能）
   - Resource Configurationに`custom-domain-name`を設定
   - Service Network Resource Associationで`private-dns-enabled`を有効化
   - VPC Endpointで`PrivateDnsPreference=ALL_DOMAINS`を設定
   - → VPC Latticeが自動的にPrivate Hosted Zoneを作成
   - → 元のRDS Proxy DNS名で接続可能

### Pattern B の利点

1. **スケーラビリティ**: Resource Configuration を追加する場合、Service Network Resource Association を追加するだけ
2. **コスト最適化**: VPC Endpoint 1個の料金（Pattern A は複数個）
3. **管理の簡素化**: VPC Endpoint を個別に管理する必要がない
4. **Aurora向け最適**: ARN-based Resource ConfigurationでPrivate DNS完全対応

### Pattern B の制約

1. **Private DNS制限**: DNS-based Resource Configuration（RDS Proxy等）ではPrivate DNS非対応
2. **Terraform Provider バグ**: Resource Configuration Association の ARN/ID 不整合問題
3. **Import が必要**: 既存の Association がある場合は import が必要
4. **RDS Proxy利用不可**: 元のDNS名で接続できないため、アプリケーション変更が必要

### 今後の検討事項

1. **パフォーマンス比較**: Pattern A との性能比較
2. **コスト比較**: VPC Endpoint 複数 vs Service Network + VPC Endpoint 1個
3. **マルチアカウント展開**: 複数の Consumer Account での利用パターン

## VPC Lattice カスタムドメイン名機能（2025年11月新機能）

### 概要

2025年11月に発表された新機能により、Resource Configurationに`custom-domain-name`を設定することで、元のAWS提供DNS名（例: `*.rds.amazonaws.com`）でリソースにアクセスできるようになりました。

**参考**: [Custom domain names for VPC Lattice resources](https://aws.amazon.com/jp/blogs/networking-and-content-delivery/custom-domain-names-for-vpc-lattice-resources/)

### 設定方法

#### 1. Resource Configurationにカスタムドメイン名を設定

```bash
aws vpc-lattice create-resource-configuration \
  --name pattern-b-rds-proxy-custom-domain \
  --type SINGLE \
  --resource-gateway-identifier rgw-xxx \
  --resource-configuration-definition '{
    "dnsResource": {
      "domainName": "pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com",
      "ipAddressType": "IPV4"
    }
  }' \
  --custom-domain-name "pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com" \
  --port-ranges 5432 \
  --protocol TCP
```

#### 2. Service Network Resource Associationで Private DNS を有効化

```bash
aws vpc-lattice create-service-network-resource-association \
  --resource-configuration-identifier rcfg-xxx \
  --service-network-identifier sn-xxx \
  --private-dns-enabled
```

#### 3. VPC Endpointで Private DNS Preference を設定

```bash
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxx \
  --service-network-arn arn:aws:vpc-lattice:... \
  --vpc-endpoint-type ServiceNetwork \
  --subnet-ids subnet-xxx subnet-yyy \
  --security-group-ids sg-xxx \
  --private-dns-enabled \
  --dns-options '{"PrivateDnsPreference": "ALL_DOMAINS"}'
```

### Private DNS Preference オプション

- `ALL_DOMAINS`: すべてのカスタムドメイン名に対してPrivate Hosted Zoneを作成
- `VERIFIED_DOMAINS_ONLY`: 検証済みドメインのみ（デフォルト）
- `VERIFIED_DOMAINS_AND_SPECIFIED_DOMAINS`: 検証済み + 指定ドメイン
- `SPECIFIED_DOMAINS_ONLY`: 指定ドメインのみ

### 動作の仕組み

1. **VPC Latticeが自動的にPrivate Hosted Zoneを作成**
   - Consumer VPCに関連付けられる
   - `Owner.OwningService: "vpc-lattice.amazonaws.com"`で管理される

2. **DNS名前解決**
   - ECSタスクが`pattern-b-rds-proxy.proxy-*.rds.amazonaws.com`をクエリ
   - VPC LatticeのDNSリゾルバーが応答
   - VPC Lattice管理のIPアドレス（10.0.x.x）に解決

3. **接続確立**
   - VPC Lattice経由でResource Gatewayにルーティング
   - Provider VPCのRDS Proxyに接続

### 検証結果（2025-11-20）

**RDS Proxy Writer Endpoint:**
```bash
# DNS解決テスト
$ getent ahosts pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
10.0.1.173      STREAM pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
# ✅ VPC Lattice管理のIPアドレスに解決

# 接続テスト
$ psql -h pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb
 current_user | inet_server_addr | version
--------------+------------------+--------------------------------------------------------------------------------------------------
 postgres     | 10.1.2.149       | PostgreSQL 15.10 on x86_64-pc-linux-gnu, compiled by x86_64-pc-linux-gnu-gcc (GCC) 9.5.0, 64-bit
# ✅ 接続成功（10.1.2.149 = Provider VPCのRDS Proxy）
```

**RDS Proxy Reader Endpoint:**
```bash
# DNS解決テスト
$ getent ahosts pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
10.0.1.162      STREAM pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com
# ✅ VPC Lattice管理のIPアドレスに解決

# 接続テスト
$ psql -h pattern-b-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb
 current_user | inet_server_addr | pg_is_in_recovery
--------------+------------------+-------------------
 postgres     | 10.1.1.184       | t
# ✅ 接続成功（10.1.1.184 = Provider VPCのAurora Reader、Read-only確認）
```

### VPC Lattice管理のPrivate Hosted Zone確認

```bash
$ aws route53 list-hosted-zones-by-vpc --vpc-id vpc-xxx --vpc-region ap-northeast-1
{
  "HostedZoneSummaries": [
    {
      "HostedZoneId": "Z07741592ROYY7YXPIC5D",
      "Name": "pattern-b-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com.",
      "Owner": {
        "OwningService": "vpc-lattice.amazonaws.com"
      }
    }
  ]
}
# ✅ VPC Latticeが自動作成したPrivate Hosted Zone
```

### Terraform対応状況

**現状**: AWS Provider 6.21.0時点では`custom-domain-name`パラメータ未サポート

**回避策**: AWS CLIで手動作成後、Terraformで管理外とするか、Provider更新を待つ

### 利点

1. **手動設定不要**: Private Hosted Zoneの手動作成が不要
2. **AWS提供ドメイン対応**: `*.rds.amazonaws.com`のようなAWS提供ドメインでも使用可能
3. **Domain Verification不要**: 未検証ドメインとして扱われるが、`ALL_DOMAINS`設定で利用可能
4. **アプリケーション変更不要**: 元のDNS名をそのまま使用可能
