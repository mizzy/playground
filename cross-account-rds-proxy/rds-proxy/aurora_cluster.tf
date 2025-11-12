# Security Group for Aurora Cluster
resource "aws_security_group" "aurora" {
  name        = "rds-proxy-aurora-sg"
  description = "Security group for Aurora cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Allow traffic from Resource Gateway security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-proxy-aurora-sg"
  }
}

# Secrets Manager for Aurora credentials
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name                    = "rds-proxy-aurora-credentials"
  description             = "Aurora master user credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = "change-me-later" # TODO: 強力なパスワードに変更
  })
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "rds-proxy-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "15.10"
  database_name           = "mydb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.aurora_credentials.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.aurora_credentials.secret_string)["password"]
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.aurora.id]
  skip_final_snapshot     = true
  backup_retention_period = 7

  tags = {
    Name = "rds-proxy-cluster"
  }
}

# Aurora Instance
resource "aws_rds_cluster_instance" "main" {
  identifier         = "rds-proxy-instance-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = "15.10"

  tags = {
    Name = "rds-proxy-instance-1"
  }
}
