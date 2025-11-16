output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "service_network_id" {
  description = "ID of the VPC Lattice Service Network"
  value       = aws_vpclattice_service_network.main.id
}

output "service_network_arn" {
  description = "ARN of the VPC Lattice Service Network"
  value       = aws_vpclattice_service_network.main.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.postgres_client.arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
}
