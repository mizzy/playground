variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the bastion task"
  type        = list(string)
}

variable "aurora_security_group_id" {
  description = "Security group ID of the Aurora cluster"
  type        = string
}

variable "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  type        = string
}

variable "database_name" {
  description = "Database name to connect to"
  type        = string
}

variable "database_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "database_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database password (optional)"
  type        = string
  default     = ""
}

variable "container_image" {
  description = "Container image for the bastion task"
  type        = string
  default     = "public.ecr.aws/docker/library/postgres:15-alpine"
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for the task in MB (512, 1024, 2048, etc.)"
  type        = string
  default     = "512"
}

variable "enable_service" {
  description = "Whether to create an ECS service for always-running bastion"
  type        = bool
  default     = false
}

variable "service_desired_count" {
  description = "Desired count for the ECS service"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
