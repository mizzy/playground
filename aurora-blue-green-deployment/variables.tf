variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "aurora-bg"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "aurora-blue-green-deployment"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# Aurora Variables
variable "database_name" {
  description = "The name of the database"
  type        = string
  default     = "mydb"
}

variable "master_username" {
  description = "The master username for the database"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "master_password" {
  description = "The master password for the database"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "instance_class" {
  description = "The instance class for Aurora instances"
  type        = string
  default     = "db.t4g.medium"
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances in the cluster"
  type        = number
  default     = 2
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.6"
}

variable "backup_retention_period" {
  description = "The backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "The preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "The interval for collecting enhanced monitoring metrics"
  type        = number
  default     = 60
}

variable "enable_enhanced_monitoring" {
  description = "Enable RDS enhanced monitoring"
  type        = bool
  default     = false
}

# Bastion ECS Variables
variable "bastion_container_image" {
  description = "Container image for the bastion task"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023"
}

variable "bastion_task_cpu" {
  description = "CPU units for the bastion task"
  type        = string
  default     = "256"
}

variable "bastion_task_memory" {
  description = "Memory for the bastion task in MB"
  type        = string
  default     = "512"
}

variable "bastion_enable_service" {
  description = "Whether to create an ECS service for always-running bastion"
  type        = bool
  default     = false
}

variable "bastion_service_desired_count" {
  description = "Desired count for the bastion ECS service"
  type        = number
  default     = 1
}
