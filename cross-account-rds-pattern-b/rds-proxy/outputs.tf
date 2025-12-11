output "rds_cluster_arn" {
  description = "ARN of the RDS cluster"
  value       = aws_rds_cluster.main.arn
}

output "rds_cluster_endpoint" {
  description = "Endpoint of the RDS cluster"
  value       = aws_rds_cluster.main.endpoint
}

output "resource_gateway_id" {
  description = "ID of the VPC Lattice Resource Gateway"
  value       = aws_vpclattice_resource_gateway.main.id
}

output "aurora_resource_configuration_arn" {
  description = "ARN of the Aurora Cluster Resource Configuration"
  value       = aws_vpclattice_resource_configuration.rds_cluster.arn
}

output "resource_configuration_id" {
  description = "ID of the Resource Configuration"
  value       = aws_vpclattice_resource_configuration.rds_cluster.id
}

output "resource_share_arn" {
  description = "ARN of the RAM Resource Share"
  value       = aws_ram_resource_share.resource_config.arn
}
