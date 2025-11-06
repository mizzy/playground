# RDS Proxy Additional Endpoint in shared subnets
# This endpoint allows cross-account access from rds-client account

# Data source to get shared subnets by CIDR block
data "aws_subnet" "shared_subnet_a" {
  filter {
    name   = "cidr-block"
    values = ["10.0.1.0/24"]
  }

  filter {
    name   = "owner-id"
    values = ["914357407416"]
  }
}

data "aws_subnet" "shared_subnet_c" {
  filter {
    name   = "cidr-block"
    values = ["10.0.2.0/24"]
  }

  filter {
    name   = "owner-id"
    values = ["914357407416"]
  }
}

# Security group for RDS Proxy endpoint in shared VPC
resource "aws_security_group" "proxy_endpoint" {
  name        = "rds-proxy-endpoint-sg"
  description = "Security group for RDS Proxy cross-account endpoint"
  vpc_id      = data.aws_subnet.shared_subnet_a.vpc_id

  # Allow PostgreSQL access (will be configured from rds-client)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-proxy-endpoint-sg"
  }
}

# Additional endpoint in rds-client subnets
resource "aws_db_proxy_endpoint" "cross_account" {
  db_proxy_name          = aws_db_proxy.main.name
  db_proxy_endpoint_name = "cross-account-endpoint"
  vpc_subnet_ids = [
    data.aws_subnet.shared_subnet_a.id,
    data.aws_subnet.shared_subnet_c.id,
  ]
  vpc_security_group_ids = [aws_security_group.proxy_endpoint.id]
  target_role            = "READ_WRITE"

  tags = {
    Name = "rds-proxy-cross-account-endpoint"
  }
}

# Output the endpoint for rds-client to use
output "cross_account_proxy_endpoint" {
  description = "RDS Proxy cross-account endpoint"
  value       = aws_db_proxy_endpoint.cross_account.endpoint
}
