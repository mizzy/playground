output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.bastion.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.bastion.arn
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.bastion.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.bastion.family
}

output "security_group_id" {
  description = "Security group ID for the bastion task"
  value       = aws_security_group.bastion.id
}

output "task_role_arn" {
  description = "ARN of the task IAM role"
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "ARN of the task execution IAM role"
  value       = aws_iam_role.task_execution.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.bastion.name
}

output "service_name" {
  description = "Name of the ECS service (if enabled)"
  value       = var.enable_service ? aws_ecs_service.bastion[0].name : null
}
