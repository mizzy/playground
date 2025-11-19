# Security Group for RDS Proxy
resource "aws_security_group" "proxy" {
  name        = "pattern-c-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "PostgreSQL from local VPC"
  }

  # Allow traffic from Resource Gateway
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
    description = "PostgreSQL from Resource Gateway (self)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "pattern-c-proxy-sg"
  }
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy" {
  name = "pattern-c-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "pattern-c-proxy-role"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager
resource "aws_iam_role_policy" "proxy_secrets" {
  name = "pattern-c-proxy-secrets-policy"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.aurora_credentials.arn
      }
    ]
  })
}

# RDS Proxy
resource "aws_db_proxy" "main" {
  name          = "pattern-c-rds-proxy"
  engine_family = "POSTGRESQL"
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.aurora_credentials.arn
  }
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  vpc_security_group_ids = [aws_security_group.proxy.id]
  require_tls            = false

  tags = {
    Name = "pattern-c-rds-proxy"
  }
}

# RDS Proxy Target Group
resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

# RDS Proxy Target
resource "aws_db_proxy_target" "main" {
  db_proxy_name         = aws_db_proxy.main.name
  target_group_name     = aws_db_proxy_default_target_group.main.name
  db_cluster_identifier = aws_rds_cluster.main.cluster_identifier
}

# RDS Proxy Reader Endpoint for read/write split
resource "aws_db_proxy_endpoint" "reader" {
  db_proxy_name          = aws_db_proxy.main.name
  db_proxy_endpoint_name = "pattern-c-rds-proxy-reader"
  vpc_subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  vpc_security_group_ids = [aws_security_group.proxy.id]
  target_role            = "READ_ONLY"

  tags = {
    Name = "pattern-c-rds-proxy-reader-endpoint"
  }
}
