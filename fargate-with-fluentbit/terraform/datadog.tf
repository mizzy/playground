resource "aws_ssm_parameter" "datadog_api_key" {
  name  = "/dev/datadog_api_key"
  type  = "SecureString"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}
