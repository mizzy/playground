# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "main" {
  name = "rds-client-service-network"

  tags = {
    Name = "rds-client-service-network"
  }
}

# Associate VPC with Service Network
resource "aws_vpclattice_service_network_vpc_association" "main" {
  vpc_identifier             = aws_vpc.main.id
  service_network_identifier = aws_vpclattice_service_network.main.id
  security_group_ids         = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "rds-client-vpc-association"
  }
}

# Associate shared Aurora Resource Configuration with Service Network
resource "aws_vpclattice_service_network_resource_association" "aurora" {
  resource_configuration_identifier = "rcfg-043b04bc49c571d1c"
  service_network_identifier        = aws_vpclattice_service_network.main.id

  tags = {
    Name = "aurora-resource-association"
  }
}

# Associate shared RDS Proxy Resource Configuration with Service Network
resource "aws_vpclattice_service_network_resource_association" "rds_proxy" {
  resource_configuration_identifier = "rcfg-0d79daf28b2309dc3"
  service_network_identifier        = aws_vpclattice_service_network.main.id

  tags = {
    Name = "rds-proxy-resource-association"
  }
}

# Outputs
output "service_network_id" {
  value = aws_vpclattice_service_network.main.id
}

output "service_network_arn" {
  value = aws_vpclattice_service_network.main.arn
}
