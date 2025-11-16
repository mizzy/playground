# Resource Configuration for RDS Proxy Default Endpoint (Writer)
resource "aws_vpclattice_resource_configuration" "rds_proxy" {
  name                        = "aurora-rds-proxy-config"
  type                        = "SINGLE"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.main.id

  resource_configuration_definition {
    dns_resource {
      domain_name     = aws_db_proxy.main.endpoint
      ip_address_type = "IPV4"
    }
  }

  port_ranges = ["5432"]
  protocol    = "TCP"

  tags = {
    Name = "aurora-rds-proxy-resource-config"
  }
}

# Resource Configuration for RDS Proxy Reader Endpoint
resource "aws_vpclattice_resource_configuration" "rds_proxy_reader" {
  name                        = "aurora-rds-proxy-reader-config"
  type                        = "SINGLE"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.main.id

  resource_configuration_definition {
    dns_resource {
      domain_name     = aws_db_proxy_endpoint.reader.endpoint
      ip_address_type = "IPV4"
    }
  }

  port_ranges = ["5432"]
  protocol    = "TCP"

  tags = {
    Name = "aurora-rds-proxy-reader-resource-config"
  }
}

# Share RDS Proxy Resource Configuration via RAM
resource "aws_ram_resource_association" "rds_proxy" {
  resource_arn       = aws_vpclattice_resource_configuration.rds_proxy.arn
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}

resource "aws_ram_resource_association" "rds_proxy_reader" {
  resource_arn       = aws_vpclattice_resource_configuration.rds_proxy_reader.arn
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}
