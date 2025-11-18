# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "rds-client-vpc"
  }
}

# Private Subnets (ECS Fargateタスク実行用)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "rds-client-private-a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "rds-client-private-c"
  }
}

# VPC Endpoints for private subnet access
# ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "rds-client-ecr-api-endpoint"
  }
}

# ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "rds-client-ecr-dkr-endpoint"
  }
}

# CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "rds-client-logs-endpoint"
  }
}

# S3 Gateway Endpoint (for ECR to pull images)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "rds-client-s3-endpoint"
  }
}

# VPC Lattice Resource Endpoint (for Aurora Resource Configuration)
resource "aws_vpc_endpoint" "resource_aurora" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-059d729fa2a6dabf2"
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled        = true

  tags = {
    Name = "rds-client-resource-endpoint-aurora"
  }
}

# VPC Lattice Resource Endpoint (for RDS Proxy Resource Configuration)
resource "aws_vpc_endpoint" "resource_rds_proxy" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-0e72a2deaf3ea0b99"
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled        = true

  tags = {
    Name = "rds-client-resource-endpoint-rds-proxy"
  }
}

# VPC Lattice Resource Endpoint (for RDS Proxy Reader Resource Configuration)
resource "aws_vpc_endpoint" "resource_rds_proxy_reader" {
  vpc_id                     = aws_vpc.main.id
  resource_configuration_arn = "arn:aws:vpc-lattice:ap-northeast-1:000767026184:resourceconfiguration/rcfg-061957ba969a47556"
  vpc_endpoint_type          = "Resource"
  subnet_ids                 = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids         = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled        = true

  tags = {
    Name = "rds-client-resource-endpoint-rds-proxy-reader"
  }
}

# VPC Lattice Service Network Endpoint (併用テスト)
resource "aws_vpc_endpoint" "service_network" {
  vpc_id              = aws_vpc.main.id
  service_network_arn = aws_vpclattice_service_network.main.arn
  vpc_endpoint_type   = "ServiceNetwork"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "rds-client-service-network-endpoint"
  }
}

# Route Table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rds-client-private-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "rds-client-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Allow PostgreSQL traffic for VPC Lattice
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "rds-client-vpc-endpoints-sg"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "rds-client-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-client-ecs-tasks-sg"
  }
}
