# Security group for RDS Proxy additional endpoint in rds-client VPC
resource "aws_security_group" "proxy_endpoint" {
  name        = "rds-proxy-endpoint-sg"
  description = "Security group for RDS Proxy cross-account endpoint"
  vpc_id      = aws_vpc.main.id

  # Allow PostgreSQL from ECS tasks
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # Allow all outbound
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

# Output the security group ID for use in rds-proxy
output "proxy_endpoint_security_group_id" {
  description = "Security Group ID for RDS Proxy endpoint"
  value       = aws_security_group.proxy_endpoint.id
}
