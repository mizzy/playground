# データベース接続に必要なリソース（VPC Lattice Resource Endpoints）

# Security Group for Database Endpoints
resource "aws_security_group" "database" {
  name        = "pattern-a-database-sg"
  description = "Security group for database endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "pattern-a-database-sg"
  }
}

# Resource Endpoint for Aurora Cluster
# NOTE: Update resource_configuration_arn after rds-proxy side is applied
resource "aws_vpc_endpoint" "aurora" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = var.aurora_resource_config_arn
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.database.id]
  private_dns_enabled        = true

  tags = {
    Name = "pattern-a-aurora-endpoint"
  }
}

# Resource Endpoint for RDS Proxy Writer
# NOTE: Update resource_configuration_arn after rds-proxy side is applied
resource "aws_vpc_endpoint" "rds_proxy_writer" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = var.rds_proxy_writer_resource_config_arn
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.database.id]
  private_dns_enabled        = true

  tags = {
    Name = "pattern-a-rds-proxy-writer-endpoint"
  }
}

# Resource Endpoint for RDS Proxy Reader
# NOTE: Update resource_configuration_arn after rds-proxy side is applied
resource "aws_vpc_endpoint" "rds_proxy_reader" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = var.rds_proxy_reader_resource_config_arn
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.database.id]
  private_dns_enabled        = true

  tags = {
    Name = "pattern-a-rds-proxy-reader-endpoint"
  }
}
