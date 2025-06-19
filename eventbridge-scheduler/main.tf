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

module "scheduler" {
  source                = "./module"
  name                  = "ecs-task-schedule"
  scheduler_policy_json = data.aws_iam_policy_document.scheduler_policy.json
  schedule_expression   = "cron(*/5 * * * ? *)" # 毎時5分ごとに実行
  target_arn            = "arn:aws:ecs:ap-northeast-1:019115212452:cluster/example"

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
