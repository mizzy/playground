variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "my-app-cluster"
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "my-app-service"
}

variable "schedule_expression" {
  description = "EventBridge Scheduler schedule expression"
  type        = string
  default     = "rate(1 hour)"
}

variable "timezone" {
  description = "Timezone for the schedule"
  type        = string
  default     = "Asia/Tokyo"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 8
}
