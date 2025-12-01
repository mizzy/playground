output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "exec_audit_log_group" {
  description = "CloudWatch log group for ECS Exec audit logs"
  value       = aws_cloudwatch_log_group.ecs_exec_audit.name
}

output "container_log_group" {
  description = "CloudWatch log group for container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
