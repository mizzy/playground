resource "datadog_integration_aws_account" "foo" {
  account_tags   = ["env:prod"]
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = "aws"

  aws_regions {
    include_only = ["ap-northeast-1"]
  }

  auth_config {
    aws_auth_config_role {
      role_name = "DatadogIntegrationRole"
    }
  }

  metrics_config {
    automute_enabled          = true
    collect_cloudwatch_alarms = true
    collect_custom_metrics    = true
    enabled                   = true

    namespace_filters {
      exclude_only = ["AWS/SQS", "AWS/ElasticMapReduce"]
    }
  }

  resources_config {
    cloud_security_posture_management_collection = false
    extended_collection                          = false
  }

  traces_config {
    xray_services {
      include_all = true
    }
  }

  logs_config {
    lambda_forwarder {
    }
  }
}

data "aws_servicequotas_service_quota" "dynamodb_table_count" {
  service_code = "dynamodb"
  quota_name   = "Maximum number of tables"
}

resource "datadog_monitor" "dynamodb_table_count_quota" {
  include_tags        = true
  message             = "@slack-mizzy-test"
  name                = "DynamoDB Table Count Quota"
  on_missing_data     = "default"
  query               = "max(last_5m):avg:aws.usage.resource_count.maximum{resource:tablecount} / ${data.aws_servicequotas_service_quota.dynamodb_table_count.value} * 100 > 80"
  type                = "query alert"
  require_full_window = false

  monitor_thresholds {
    critical = "80"
  }
}
