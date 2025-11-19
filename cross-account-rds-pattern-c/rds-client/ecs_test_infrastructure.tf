# ECS Testing Infrastructure

# ECR Repository for PostgreSQL client image
resource "aws_ecr_repository" "postgres_client" {
  name                 = "pattern-c-postgres-client"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "pattern-c-postgres-client"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "test" {
  name = "pattern-c-test-cluster"

  tags = {
    Name = "pattern-c-test-cluster"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "pattern-c-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "pattern-c-ecs-tasks-sg"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "pattern-c-ecs-task-execution-role"

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

  tags = {
    Name = "pattern-c-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for the task itself)
resource "aws_iam_role" "ecs_task" {
  name = "pattern-c-ecs-task-role"

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

  tags = {
    Name = "pattern-c-ecs-task-role"
  }
}

# Policy for ECS Exec
resource "aws_iam_role_policy" "ecs_exec" {
  name = "pattern-c-ecs-exec-policy"
  role = aws_iam_role.ecs_task.id

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

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "/ecs/pattern-c-postgres-test"
  retention_in_days = 1

  tags = {
    Name = "pattern-c-ecs-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "postgres_test" {
  family                   = "pattern-c-postgres-test"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "postgres-client"
      image = "${aws_ecr_repository.postgres_client.repository_url}:amd64"
      command = [
        "/bin/sh",
        "-c",
        "while true; do sleep 3600; done"
      ]
      essential = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "postgres-test"
        }
      }

      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])

  tags = {
    Name = "pattern-c-postgres-test"
  }
}
