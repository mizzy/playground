resource "datadog_integration_aws_account" "foo" {
  account_tags = ["env:prod"]
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
