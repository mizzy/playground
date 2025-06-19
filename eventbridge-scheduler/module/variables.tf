variable "name" {
  type = string
}

variable "scheduler_policy_json" {
  type = string
}

variable "schedule_expression" {
  type = string
}

variable "schedule_expression_timezone" {
  type    = string
  default = "Asia/Tokyo"
}

variable "target_arn" {
  type = string
}

variable "ecs_parameters" {
  type = object({
    task_definition_arn = string
    launch_type         = optional(string, "FARGATE")

    network_configuration = object({
      security_groups = list(string)
      subnets         = list(string)
    })

    container_overrides = optional(list(object({
      name    = string
      command = optional(list(string), [])
    })), null)
  })

  default = null
}

variable "retry_policy" {
  type = object({
    maximum_event_age_in_seconds = number
    maximum_retry_attempts       = number
  })

  default = {
    maximum_event_age_in_seconds = 86400
    maximum_retry_attempts       = 185
  }
}
