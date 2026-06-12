variable "client_account_id" {
  description = "RDSクライアントが存在するAWSアカウントID"
  type        = string
  default     = "914357407416"
}

variable "client_vpc_id" {
  description = "クライアントアカウント側のVPC ID(クライアントアカウントのStep 1適用後に設定する)"
  type        = string
}

variable "client_vpc_cidr" {
  description = "クライアントアカウント側のVPC CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "peering_accepted" {
  description = "VPC Peeringがクライアントアカウント側で承認済みかどうか(承認後にtrueにしてルートを作成する)"
  type        = bool
  default     = false
}

locals {
  name        = "cross-account-iam-auth"
  db_username = "dbadmin"
}
