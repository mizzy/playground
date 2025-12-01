# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# CloudWatch Log Group for ECS Exec audit logs
resource "aws_cloudwatch_log_group" "ecs_exec_audit" {
  name              = "/ecs/${var.project_name}/exec-audit"
  retention_in_days = 7
}
