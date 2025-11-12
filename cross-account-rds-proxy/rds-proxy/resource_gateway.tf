# Resource Gateway for VPC
resource "aws_vpclattice_resource_gateway" "main" {
  name   = "rds-proxy-resource-gateway"
  vpc_id = aws_vpc.main.id
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]
  security_group_ids = [aws_security_group.proxy.id]

  tags = {
    Name = "rds-proxy-resource-gateway"
  }
}

# Resource Configuration for Aurora Cluster
resource "aws_vpclattice_resource_configuration" "aurora" {
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

# RAM Resource Share for Resource Configuration
resource "aws_ram_resource_share" "resource_config" {
  name                      = "aurora-resource-config-share"
  allow_external_principals = true

  tags = {
    Name = "aurora-resource-config-share"
  }
}

# Associate Resource Configuration with RAM
resource "aws_ram_resource_association" "resource_config" {
  resource_arn       = aws_vpclattice_resource_configuration.aurora.arn
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}

# Share with rds-client account
resource "aws_ram_principal_association" "rds_client_account" {
  principal          = "914357407416"
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}

# Outputs
output "resource_gateway_id" {
  value = aws_vpclattice_resource_gateway.main.id
}

output "resource_configuration_arn" {
  value = aws_vpclattice_resource_configuration.aurora.arn
}

output "resource_share_arn" {
  value = aws_ram_resource_share.resource_config.arn
}
