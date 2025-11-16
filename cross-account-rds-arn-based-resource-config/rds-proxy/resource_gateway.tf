# Resource Gateway for VPC
resource "aws_vpclattice_resource_gateway" "main" {
  name   = "rds-resource-gateway"
  vpc_id = aws_vpc.main.id
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]
  security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "rds-resource-gateway"
  }
}

# Resource Configuration for Aurora Cluster (ARN-based)
resource "aws_vpclattice_resource_configuration" "rds_cluster" {
  name                        = "aurora-cluster-config"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.main.id
  type                        = "ARN"

  # ARN-based resource configuration for Aurora Cluster
  resource_configuration_definition {
    arn_resource {
      arn = aws_rds_cluster.main.arn
    }
  }

  tags = {
    Name = "aurora-cluster-resource-config"
  }
}
