# Security Group for RDS Proxy
resource "aws_security_group" "proxy" {
  name        = "rds-proxy-sg"
  description = "Security group for RDS Proxy"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: クライアントアカウントのCIDRに制限する
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-proxy-sg"
  }
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy" {
  name = "rds-proxy-role"

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
    Name = "rds-proxy-role"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager
resource "aws_iam_role_policy" "proxy_secrets" {
  name = "rds-proxy-secrets-policy"
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
  name          = "rds-proxy"
  engine_family = "POSTGRESQL"
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.aurora_credentials.arn
  }
  role_arn       = aws_iam_role.proxy.arn
  vpc_subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  require_tls    = false

  tags = {
    Name = "rds-proxy"
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
