variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "fargate-rds-bastion"
}

variable "db_master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "dbadmin"
}

variable "db_master_password" {
  description = "Master password for Aurora"
  type        = string
  sensitive   = true
}
