output "vpc_id" {
  description = "RDSアカウント側のVPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "RDSアカウント側のVPC CIDR"
  value       = aws_vpc.this.cidr_block
}

output "peering_connection_id" {
  description = "VPC Peering接続ID(クライアントアカウント側で承認に使用する)"
  value       = aws_vpc_peering_connection.to_client.id
}

output "rds_proxy_endpoint" {
  description = "RDS Proxyのエンドポイント"
  value       = aws_db_proxy.this.endpoint
}

output "rds_proxy_resource_id" {
  description = "RDS ProxyのリソースID(rds-db:connectのリソースARNに使用する)"
  value       = local.proxy_resource_id
}

output "db_connect_role_arn" {
  description = "クライアントアカウントからAssumeRoleするDB接続用IAMロールのARN"
  value       = aws_iam_role.db_connect.arn
}

output "db_user_arn" {
  description = "rds-db:connectの対象となるdbuser ARN"
  value       = local.db_user_arn
}

output "db_username" {
  description = "IAM認証で接続するDBユーザー名"
  value       = local.db_username
}
