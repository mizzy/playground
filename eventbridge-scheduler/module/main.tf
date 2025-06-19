resource "aws_scheduler_schedule" "this" {
  name = var.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_expression_timezone

  target {
    arn      = var.target_arn
    role_arn = var.target_role_arn

    dynamic "ecs_parameters" {
      for_each = var.ecs_parameters != null ? [1] : []
      content {
        task_definition_arn = var.ecs_parameters.task_definition_arn
        launch_type         = var.ecs_parameters.launch_type

        network_configuration {
          assign_public_ip = false
          security_groups  = var.ecs_parameters.network_configuration.security_groups
          subnets          = var.ecs_parameters.network_configuration.subnets
        }
      }
    }

    input = var.ecs_parameters.container_overrides != null ? jsonencode({
      containerOverrides = var.ecs_parameters.container_overrides
    }) : null

    retry_policy {
      maximum_event_age_in_seconds = var.retry_policy.maximum_event_age_in_seconds
      maximum_retry_attempts       = var.retry_policy.maximum_retry_attempts
    }
  }
}
