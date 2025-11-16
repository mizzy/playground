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

output "resource_configuration_arn" {
  description = "ARN of the Resource Configuration"
  value       = aws_vpclattice_resource_configuration.rds_cluster.arn
}

output "resource_configuration_id" {
  description = "ID of the Resource Configuration"
  value       = aws_vpclattice_resource_configuration.rds_cluster.id
}
