# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "rds-client-cluster"

  tags = {
    Name = "rds-client-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "/ecs/rds-client-tasks"
  retention_in_days = 7

  tags = {
    Name = "rds-client-ecs-tasks-logs"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "rds-client-ecs-task-execution-role"

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

  tags = {
    Name = "rds-client-ecs-task-execution-role"
  }
}

# Attach ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (アプリケーションが使用するロール)
resource "aws_iam_role" "ecs_task" {
  name = "rds-client-ecs-task-role"

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

  tags = {
    Name = "rds-client-ecs-task-role"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "postgres_test" {
  family                   = "rds-proxy-test"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "postgres-client"
      image = "postgres:15"
      command = [
        "sh",
        "-c",
        "echo 'Testing connection to RDS Proxy...' && PGPASSWORD='${var.db_password}' psql -h ${var.rds_proxy_endpoint} -U ${var.db_username} -d ${var.db_name} -c 'SELECT version();' && echo 'Connection successful!' && sleep 30"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "postgres-test"
        }
      }
    }
  ])

  tags = {
    Name = "rds-proxy-test-task"
  }
}
