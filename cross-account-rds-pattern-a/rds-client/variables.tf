variable "rds_cluster_resource_config_arn" {
  description = "ARN of Aurora cluster resource configuration from rds-proxy account"
  type        = string
}

variable "rds_proxy_resource_config_arn" {
  description = "ARN of RDS Proxy writer resource configuration from rds-proxy account"
  type        = string
}

variable "rds_proxy_reader_resource_config_arn" {
  description = "ARN of RDS Proxy reader resource configuration from rds-proxy account"
  type        = string
}
