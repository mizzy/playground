output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint"
  value       = aws_db_proxy.main.endpoint
}

output "rds_proxy_arn" {
  description = "RDS Proxy ARN"
  value       = aws_db_proxy.main.arn
}

output "proxy_security_group_id" {
  description = "RDS Proxy security group ID"
  value       = aws_security_group.proxy.id
}
