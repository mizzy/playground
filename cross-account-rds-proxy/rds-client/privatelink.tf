# VPC Endpoint to connect to RDS Proxy via PrivateLink
resource "aws_vpc_endpoint" "rds_proxy" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.vpce.ap-northeast-1.vpce-svc-07ea2277e01116068"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = false

  tags = {
    Name = "rds-proxy-privatelink-endpoint"
  }
}

# Output the VPC Endpoint DNS name
output "privatelink_endpoint_dns" {
  value       = aws_vpc_endpoint.rds_proxy.dns_entry
  description = "PrivateLink VPC Endpoint DNS entries"
}

output "privatelink_endpoint_id" {
  value       = aws_vpc_endpoint.rds_proxy.id
  description = "PrivateLink VPC Endpoint ID"
}
