terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "git::https://github.com/mizzy/terraform-modules.git//aws/vpc?ref=main"

  name       = var.name_prefix
  cidr_block = var.vpc_cidr
}

# Security Group for Aurora
resource "aws_security_group" "aurora" {
  name_prefix = "${var.name_prefix}-aurora-"
  vpc_id      = module.vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora"
    }
  )
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = [for s in module.vpc.private_subnets : s.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora"
    }
  )
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_engine_version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  skip_final_snapshot = var.skip_final_snapshot
  apply_immediately   = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.tags
}

# Aurora Instance
resource "aws_rds_cluster_instance" "aurora" {
  count = var.aurora_instance_count

  identifier         = "${var.name_prefix}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.enable_enhanced_monitoring ? aws_iam_role.monitoring[0].arn : null

  apply_immediately = true

  tags = var.tags
}

# IAM Role for Enhanced Monitoring (if enabled)
resource "aws_iam_role" "monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name_prefix = "${var.name_prefix}-aurora-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
