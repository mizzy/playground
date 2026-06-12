variable "rds_account_id" {
  description = "RDSとRDS Proxyが存在するAWSアカウントID"
  type        = string
  default     = "000767026184"
}

variable "rds_vpc_cidr" {
  description = "RDSアカウント側のVPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "peering_connection_id" {
  description = "RDSアカウント側で作成されたVPC Peering接続ID(RDSアカウントのStep 2適用後に設定する)"
  type        = string
  default     = null
}

variable "rds_proxy_resource_id" {
  description = "RDS ProxyのリソースID(RDSアカウントのStep 2適用後に設定する)"
  type        = string
  default     = null
}

variable "db_connect_role_arn" {
  description = "RDSアカウント側のDB接続用IAMロールのARN(RDSアカウントのStep 2適用後に設定する)"
  type        = string
  default     = null
}

variable "db_username" {
  description = "IAM認証で接続するDBユーザー名"
  type        = string
  default     = "dbadmin"
}

locals {
  name = "cross-account-iam-auth"
}
