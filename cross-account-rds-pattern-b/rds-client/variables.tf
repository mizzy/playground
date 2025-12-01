variable "aurora_resource_config_id" {
  description = "ID of Aurora cluster resource configuration from rds-proxy account"
  type        = string
}

variable "rds_proxy_writer_resource_config_id" {
  description = "ID of RDS Proxy writer resource configuration from rds-proxy account"
  type        = string
}

variable "rds_proxy_reader_resource_config_id" {
  description = "ID of RDS Proxy reader resource configuration from rds-proxy account"
  type        = string
}

variable "resource_share_arn" {
  description = "ARN of RAM Resource Share from rds-proxy account"
  type        = string
}
