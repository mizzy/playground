# VPC Lattice Resource Endpoint (Resource Endpoint type)
# This creates a VPC Endpoint directly to the Resource Configuration
resource "aws_vpc_endpoint" "resource" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-0542859f46e58400f"
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.ecs_tasks.id]
  private_dns_enabled        = true

  # Wait for RAM resource share to be accepted
  depends_on = [aws_ram_resource_share_accepter.resource_config]

  tags = {
    Name = "rds-cluster-resource-endpoint"
  }
}
