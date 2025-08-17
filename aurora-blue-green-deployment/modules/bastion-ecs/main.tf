# ECS Cluster for Bastion
resource "aws_ecs_cluster" "bastion" {
  name = "${var.name_prefix}-bastion-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bastion-cluster"
    }
  )
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "bastion" {
  name              = "/ecs/${var.name_prefix}-bastion"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bastion-logs"
    }
  )
}

# Security Group for Bastion ECS Task
resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Security group for Bastion ECS task"
  vpc_id      = var.vpc_id

  # Allow outbound to Aurora PostgreSQL
  egress {
    description     = "PostgreSQL to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.aurora_security_group_id]
  }

  # Allow all outbound for package installation
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
      Name = "${var.name_prefix}-bastion-sg"
    }
  )
}

# Allow ingress from Bastion to Aurora Security Group
# Note: This rule is managed separately to avoid conflicts with inline rules
resource "aws_security_group_rule" "aurora_from_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = var.aurora_security_group_id
  description              = "PostgreSQL from Bastion ECS"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "task_execution" {
  name = "${var.name_prefix}-bastion-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (with Session Manager support)
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-bastion-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Session Manager
resource "aws_iam_role_policy" "task_ssm" {
  name = "${var.name_prefix}-bastion-ssm-policy"
  role = aws_iam_role.task.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.bastion.arn}:*"
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "bastion" {
  family                   = "${var.name_prefix}-bastion"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "bastion"
      image = var.container_image

      command = [
        "sh",
        "-c",
        "yum install -y postgresql15 && tail -f /dev/null"
      ]

      essential = true

      environment = [
        {
          name  = "PGHOST"
          value = var.aurora_endpoint
        },
        {
          name  = "PGPORT"
          value = "5432"
        },
        {
          name  = "PGDATABASE"
          value = var.database_name
        },
        {
          name  = "PGUSER"
          value = var.database_username
        },
        {
          name  = "PGPASSWORD"
          value = var.database_username == "postgres" ? "ChangeMe123!" : ""
        }
      ]

      secrets = var.database_password_secret_arn != "" ? [
        {
          name      = "PGPASSWORD"
          valueFrom = var.database_password_secret_arn
        }
      ] : []

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.bastion.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# ECS Service (Optional - for always-running bastion)
resource "aws_ecs_service" "bastion" {
  count = var.enable_service ? 1 : 0

  name            = "${var.name_prefix}-bastion-service"
  cluster         = aws_ecs_cluster.bastion.id
  task_definition = aws_ecs_task_definition.bastion.arn
  desired_count   = var.service_desired_count

  launch_type = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.bastion.id]
    assign_public_ip = false
  }

  enable_execute_command = true

  tags = var.tags
}
