output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = aws_vpc.main.cidr_block
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.postgres_test.arn
}

output "ecs_security_group_id" {
  description = "ECS Tasks Security Group ID"
  value       = aws_security_group.ecs_tasks.id
}

output "subnet_ids" {
  description = "Private Subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
}

output "test_command" {
  description = "Command to run ECS task for testing"
  value       = <<-EOT
    aws-vault exec rds-client -- aws ecs run-task \
      --cluster ${aws_ecs_cluster.main.name} \
      --task-definition ${aws_ecs_task_definition.postgres_test.family} \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.private_a.id},${aws_subnet.private_c.id}],securityGroups=[${aws_security_group.ecs_tasks.id}],assignPublicIp=DISABLED}"
  EOT
}
