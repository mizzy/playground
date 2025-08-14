# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.name_prefix}-aurora-subnet-group"
  subnet_ids = [for s in module.vpc.private_subnets : s.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora-subnet-group"
    }
  )
}

# Security Group for Aurora
resource "aws_security_group" "aurora" {
  name        = "${var.name_prefix}-aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = module.vpc.id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora-sg"
    }
  )
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora_postgresql" {
  family      = "aurora-postgresql15"
  name        = "${var.name_prefix}-aurora-pg15-cluster-params"
  description = "Aurora PostgreSQL 15 cluster parameter group"

  # Blue/Green deployment parameters
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

# DB Parameter Group
resource "aws_db_parameter_group" "aurora_postgresql" {
  family      = "aurora-postgresql15"
  name        = "${var.name_prefix}-aurora-pg15-params"
  description = "Aurora PostgreSQL 15 parameter group"

  tags = var.tags
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora_postgresql" {
  cluster_identifier              = "${var.name_prefix}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.6"
  database_name                   = var.database_name
  master_username                 = var.master_username
  master_password                 = var.master_password
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_postgresql.name

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora-cluster"
    }
  )
}

# Aurora Instances
resource "aws_rds_cluster_instance" "aurora_instance" {
  count = var.instance_count
  
  identifier                   = "${var.name_prefix}-aurora-instance-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.aurora_postgresql.id
  instance_class               = var.instance_class
  engine                       = aws_rds_cluster.aurora_postgresql.engine
  engine_version               = aws_rds_cluster.aurora_postgresql.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_postgresql.name
  
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-aurora-instance-${count.index + 1}"
    }
  )
}

# IAM Role for Enhanced Monitoring (optional)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Outputs
output "aurora_cluster_endpoint" {
  description = "The cluster endpoint"
  value       = aws_rds_cluster.aurora_postgresql.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = aws_rds_cluster.aurora_postgresql.reader_endpoint
}

output "aurora_cluster_id" {
  description = "The RDS Cluster ID"
  value       = aws_rds_cluster.aurora_postgresql.id
}

output "aurora_instance_ids" {
  description = "List of RDS instance identifiers"
  value       = aws_rds_cluster_instance.aurora_instance[*].id
}

output "aurora_instance_endpoints" {
  description = "List of RDS instance endpoints"
  value       = aws_rds_cluster_instance.aurora_instance[*].endpoint
}

output "aurora_security_group_id" {
  description = "The security group ID for Aurora"
  value       = aws_security_group.aurora.id
}
