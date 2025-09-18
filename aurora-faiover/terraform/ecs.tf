# ECS Cluster
resource "aws_ecs_cluster" "aurora_failover" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/ecs/aurora-failover-typescript-app"
  retention_in_days = 7

  tags = var.tags
}

# CloudWatch Log Group for DB Monitor
resource "aws_cloudwatch_log_group" "ecs_db_monitor" {
  name              = "/ecs/aurora-failover-db-monitor"
  retention_in_days = 7

  tags = var.tags
}

# Security Group for ECS App
resource "aws_security_group" "ecs_app" {
  name_prefix = "${var.name_prefix}-ecs-app-"
  vpc_id      = module.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
      Name = "${var.name_prefix}-ecs-app"
    }
  )
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name_prefix = "${var.name_prefix}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Parameter Store access
resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name_prefix = "${var.name_prefix}-exec-ssm-"
  role        = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/aurora-failover/*"
      }
    ]
  })
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name_prefix = "${var.name_prefix}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Policy for ECS Exec
resource "aws_iam_role_policy" "ecs_task_exec" {
  name_prefix = "${var.name_prefix}-task-exec-"
  role        = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Parameter Store for database connection
resource "aws_ssm_parameter" "db_host" {
  name  = "/aurora-failover/db/host"
  type  = "String"
  value = aws_rds_cluster.aurora.endpoint

  tags = var.tags
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/aurora-failover/db/user"
  type  = "String"
  value = var.master_username

  tags = var.tags
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/aurora-failover/db/password"
  type  = "SecureString"
  value = var.master_password

  tags = var.tags
}
