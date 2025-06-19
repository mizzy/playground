resource "aws_iam_role" "scheduler" {
  name = "scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "scheduler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask",
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-1:019115212452:task-definition/httpd:*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole",
    ]

    resources = [
      "arn:aws:iam::019115212452:role/httpd",     # タスク実行ロール
      "arn:aws:iam::019115212452:role/task-role", # タスクロール
    ]
  }
}

resource "aws_iam_policy" "scheduler_policy" {
  name   = "scheduler-policy"
  policy = data.aws_iam_policy_document.scheduler_policy.json
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler_policy.arn
}

module "scheduler" {
  source                       = "./module"
  name                         = "ecs-task-schedule"
  schedule_expression          = "cron(*/5 * * * ? *)" # 毎時5分ごとに実行
  schedule_expression_timezone = "Asia/Tokyo"
  target_arn                   = "arn:aws:ecs:ap-northeast-1:019115212452:cluster/example"
  target_role_arn              = aws_iam_role.scheduler.arn

  ecs_parameters = {
    task_definition_arn = "arn:aws:ecs:ap-northeast-1:019115212452:task-definition/httpd"

    network_configuration = {
      assign_public_ip = false
      security_groups  = ["sg-06d32ac4187f493de"]
      subnets          = ["subnet-00ea05b074d3d66dd"]
    }

    container_overrides = [
      {
        name    = "httpd"
        command = ["echo hogehoge"]
      }
    ]
  }
}
