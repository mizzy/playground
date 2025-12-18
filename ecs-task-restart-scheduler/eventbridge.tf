resource "aws_scheduler_schedule" "restart_oldest_task" {
  name       = "restart-oldest-ecs-task"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.timezone

  target {
    arn      = aws_sfn_state_machine.restart_oldest_task.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({})
  }
}
