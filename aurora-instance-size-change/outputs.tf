output "aurora_cluster_id" {
  description = "The RDS Cluster ID"
  value       = aws_rds_cluster.aurora.id
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint for the cluster"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_instance_ids" {
  description = "List of instance identifiers"
  value       = aws_rds_cluster_instance.aurora[*].id
}

output "aurora_instance_endpoints" {
  description = "List of instance endpoints"
  value       = aws_rds_cluster_instance.aurora[*].endpoint
}

output "aurora_security_group_id" {
  description = "Security group ID for Aurora cluster"
  value       = aws_security_group.aurora.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [for s in module.vpc.private_subnets : s.id]
}

output "database_name" {
  description = "Name of the database"
  value       = aws_rds_cluster.aurora.database_name
}

output "master_username" {
  description = "Master username"
  value       = aws_rds_cluster.aurora.master_username
  sensitive   = true
}

output "current_instance_class" {
  description = "Current instance class"
  value       = var.instance_class
}
