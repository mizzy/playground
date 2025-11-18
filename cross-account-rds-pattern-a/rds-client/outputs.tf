output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "Private Subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_c.id]
}

output "aurora_resource_endpoint_id" {
  description = "ID of Aurora Cluster Resource Endpoint"
  value       = aws_vpc_endpoint.aurora.id
}

output "rds_proxy_writer_resource_endpoint_id" {
  description = "ID of RDS Proxy Writer Resource Endpoint"
  value       = aws_vpc_endpoint.rds_proxy_writer.id
}

output "rds_proxy_reader_resource_endpoint_id" {
  description = "ID of RDS Proxy Reader Resource Endpoint"
  value       = aws_vpc_endpoint.rds_proxy_reader.id
}

output "aurora_resource_endpoint_dns_entries" {
  description = "DNS entries for Aurora Cluster Resource Endpoint"
  value       = aws_vpc_endpoint.aurora.dns_entry
}

output "rds_proxy_writer_resource_endpoint_dns_entries" {
  description = "DNS entries for RDS Proxy Writer Resource Endpoint"
  value       = aws_vpc_endpoint.rds_proxy_writer.dns_entry
}

output "rds_proxy_reader_resource_endpoint_dns_entries" {
  description = "DNS entries for RDS Proxy Reader Resource Endpoint"
  value       = aws_vpc_endpoint.rds_proxy_reader.dns_entry
}
