variable "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint from rds-proxy account"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "change-me-later"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "mydb"
}
