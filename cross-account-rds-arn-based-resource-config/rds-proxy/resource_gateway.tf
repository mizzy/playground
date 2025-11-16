# VPC Lattice Resource Gateway
resource "aws_vpclattice_resource_gateway" "main" {
  name               = "rds-resource-gateway"
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "rds-resource-gateway"
  }
}

# ARN-based Resource Configuration for RDS Cluster
resource "aws_vpclattice_resource_configuration" "rds_cluster" {
  name                        = "rds-cluster-arn-config"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.main.id
  type                        = "ARN"

  resource_configuration_definition {
    arn_resource {
      arn = aws_rds_cluster.main.arn
    }
  }

  tags = {
    Name = "rds-cluster-arn-config"
  }
}
