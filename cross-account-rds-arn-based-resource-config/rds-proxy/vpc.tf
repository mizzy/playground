# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "rds-proxy-vpc"
  }
}

# Subnet for AZ a
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "rds-proxy-private-a"
  }
}

# Subnet for AZ c
resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "rds-proxy-private-c"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "rds-proxy-rds-sg"
  description = "Security group for RDS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from local VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "PostgreSQL from rds-client VPC via VPC Lattice"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "PostgreSQL from Resource Gateway (self)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-proxy-rds-sg"
  }
}
