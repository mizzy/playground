# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "main" {
  name = "rds-client-service-network"

  tags = {
    Name = "rds-client-service-network"
  }
}

# VPC Endpoint for Service Network (ServiceNetwork type)
# This enables access to resources in the Service Network
resource "aws_vpc_endpoint" "service_network" {
  vpc_id              = aws_vpc.main.id
  vpc_endpoint_type   = "ServiceNetwork"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.ecs_tasks.id]
  private_dns_enabled = true

  # Use service_network_arn instead of service_name for ServiceNetwork type
  service_network_arn = aws_vpclattice_service_network.main.arn

  tags = {
    Name = "rds-service-network-endpoint"
  }
}

# Associate shared Aurora Resource Configuration with Service Network
resource "aws_vpclattice_service_network_resource_association" "aurora" {
  # Extract Resource Configuration ID from ARN (last part after the last '/')
  resource_configuration_identifier = element(split("/", aws_ram_resource_share_accepter.resource_config.resources[0]), length(split("/", aws_ram_resource_share_accepter.resource_config.resources[0])) - 1)
  service_network_identifier        = aws_vpclattice_service_network.main.id

  depends_on = [aws_ram_resource_share_accepter.resource_config]

  tags = {
    Name = "aurora-resource-association"
  }
}
