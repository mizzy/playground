# Service Network for VPC Lattice
# NOTE: Service Network + Resource Configuration Association approach
# The rds-proxy account shares Resource Configurations via RAM
# This rds-client account creates a Service Network and associates it with those Resource Configurations

resource "aws_vpclattice_service_network" "main" {
  name      = "pattern-c-service-network"
  auth_type = "NONE"

  tags = {
    Name = "pattern-c-service-network"
  }
}

# VPC Endpoint to connect to Service Network
# NOTE: Using VPC Endpoint approach instead of VPC Association
resource "aws_vpc_endpoint" "service_network" {
  vpc_id              = aws_vpc.main.id
  service_network_arn = aws_vpclattice_service_network.main.arn
  vpc_endpoint_type   = "ServiceNetwork"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.database.id]
  private_dns_enabled = true

  tags = {
    Name = "pattern-c-service-network-vpce"
  }
}

# Associate Service Network with Aurora Resource Configuration
resource "aws_vpclattice_service_network_resource_association" "aurora" {
  resource_configuration_identifier = var.aurora_resource_config_arn
  service_network_identifier        = aws_vpclattice_service_network.main.id

  tags = {
    Name = "pattern-c-aurora-resource-association"
  }
}

# Associate Service Network with RDS Proxy Writer Resource Configuration
resource "aws_vpclattice_service_network_resource_association" "rds_proxy_writer" {
  resource_configuration_identifier = var.rds_proxy_writer_resource_config_arn
  service_network_identifier        = aws_vpclattice_service_network.main.id

  tags = {
    Name = "pattern-c-rds-proxy-writer-resource-association"
  }
}

# Associate Service Network with RDS Proxy Reader Resource Configuration
resource "aws_vpclattice_service_network_resource_association" "rds_proxy_reader" {
  resource_configuration_identifier = var.rds_proxy_reader_resource_config_arn
  service_network_identifier        = aws_vpclattice_service_network.main.id

  tags = {
    Name = "pattern-c-rds-proxy-reader-resource-association"
  }
}
