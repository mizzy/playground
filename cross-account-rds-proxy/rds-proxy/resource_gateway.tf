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

# Resource Configuration for RDS Proxy (domain-name based)
resource "aws_vpclattice_resource_configuration" "rds_proxy" {
  name                        = "rds-proxy-config"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.main.id
  type                        = "SINGLE"
  protocol                    = "TCP"

  # Domain-name based resource configuration for RDS Proxy
  resource_configuration_definition {
    dns_resource {
      domain_name     = aws_db_proxy.main.endpoint
      ip_address_type = "IPV4"
    }
  }

  port_ranges = ["5432"]

  tags = {
    Name = "rds-proxy-resource-config"
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

# Associate Aurora Resource Configuration with RAM
resource "aws_ram_resource_association" "aurora" {
  resource_arn       = aws_vpclattice_resource_configuration.aurora.arn
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}

# Associate RDS Proxy Resource Configuration with RAM
resource "aws_ram_resource_association" "rds_proxy" {
  resource_arn       = aws_vpclattice_resource_configuration.rds_proxy.arn
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

output "resource_configuration_rds_proxy_arn" {
  value       = aws_vpclattice_resource_configuration.rds_proxy.arn
  description = "RDS Proxy Resource Configuration ARN"
}

output "resource_share_arn" {
  value = aws_ram_resource_share.resource_config.arn
}
