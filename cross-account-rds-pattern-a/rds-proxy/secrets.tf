# Secrets Manager for Aurora credentials
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name                    = "pattern-a-aurora-credentials"
  description             = "Aurora cluster credentials for RDS Proxy"
  recovery_window_in_days = 0

  tags = {
    Name = "pattern-a-aurora-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = "password123"
  })
}
