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

# VPC Association to connect to Service Network
# NOTE: Using VPC Association approach
resource "aws_vpclattice_service_network_vpc_association" "main" {
  vpc_identifier             = aws_vpc.main.id
  service_network_identifier = aws_vpclattice_service_network.main.id
  security_group_ids         = [aws_security_group.database.id]

  tags = {
    Name = "pattern-c-service-network-vpc-association"
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
