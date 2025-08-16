output "cluster_id" {
  description = "Aurora cluster ID"
  value       = aws_rds_cluster.aurora_postgresql.id
}

output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora_postgresql.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora_postgresql.reader_endpoint
}

output "instance_ids" {
  description = "List of Aurora instance IDs"
  value       = aws_rds_cluster_instance.aurora_instance[*].id
}

output "instance_endpoints" {
  description = "List of Aurora instance endpoints"
  value       = aws_rds_cluster_instance.aurora_instance[*].endpoint
}

output "security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.aurora.name
}

output "cluster_parameter_group_name" {
  description = "Cluster parameter group name"
  value       = aws_rds_cluster_parameter_group.aurora_postgresql.name
}

output "db_parameter_group_name" {
  description = "DB parameter group name"
  value       = aws_db_parameter_group.aurora_postgresql.name
}