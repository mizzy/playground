output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "aurora_instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = aws_rds_cluster_instance.aurora[*].endpoint
}

output "aurora_instance_identifiers" {
  description = "Aurora instance identifiers"
  value       = aws_rds_cluster_instance.aurora[*].identifier
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [for s in module.vpc.private_subnets : s.id]
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.aurora_failover_app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.aurora_failover_app.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.aurora_failover.arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs_app.id
}
