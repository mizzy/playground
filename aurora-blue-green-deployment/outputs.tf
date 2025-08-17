# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.id
}

output "public_subnets" {
  description = "Public subnet details"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet details"
  value       = module.vpc.private_subnets
}

# Aurora Outputs
output "aurora_cluster_id" {
  description = "Aurora cluster ID"
  value       = module.aurora.cluster_id
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "aurora_instance_ids" {
  description = "List of Aurora instance IDs"
  value       = module.aurora.instance_ids
}

output "aurora_instance_endpoints" {
  description = "List of Aurora instance endpoints"
  value       = module.aurora.instance_endpoints
}

output "aurora_security_group_id" {
  description = "Security group ID for Aurora"
  value       = module.aurora.security_group_id
}

# Bastion ECS Outputs
output "bastion_cluster_name" {
  description = "Name of the Bastion ECS cluster"
  value       = module.bastion_ecs.cluster_name
}

output "bastion_task_definition_arn" {
  description = "ARN of the Bastion task definition"
  value       = module.bastion_ecs.task_definition_arn
}

output "bastion_task_definition_family" {
  description = "Family of the Bastion task definition"
  value       = module.bastion_ecs.task_definition_family
}

output "bastion_security_group_id" {
  description = "Security group ID for the Bastion task"
  value       = module.bastion_ecs.security_group_id
}

output "bastion_log_group_name" {
  description = "CloudWatch log group name for Bastion"
  value       = module.bastion_ecs.log_group_name
}

output "bastion_connect_command" {
  description = "AWS CLI command to connect to the bastion"
  value       = <<-EOT
    aws ecs execute-command \
      --cluster ${module.bastion_ecs.cluster_name} \
      --task <TASK_ID> \
      --container bastion \
      --interactive \
      --command "/bin/sh"
  EOT
}

output "bastion_run_task_command" {
  description = "AWS CLI command to run a new bastion task"
  value       = <<-EOT
    aws ecs run-task \
      --cluster ${module.bastion_ecs.cluster_name} \
      --task-definition ${module.bastion_ecs.task_definition_family} \
      --network-configuration "awsvpcConfiguration={subnets=[${join(",", [for s in module.vpc.private_subnets : s.id])}],securityGroups=[${module.bastion_ecs.security_group_id}],assignPublicIp=DISABLED}" \
      --enable-execute-command \
      --launch-type FARGATE
  EOT
}

# DMS Rollback Outputs (conditional)
# DMSモジュールが有効化されたらコメントを外してください
# output "dms_rollback_cluster_id" {
#   description = "Rollback Aurora cluster ID"
#   value       = var.enable_dms_rollback ? module.dms_rollback.rollback_cluster_id : null
# }
#
# output "dms_rollback_cluster_endpoint" {
#   description = "Rollback Aurora cluster endpoint"
#   value       = var.enable_dms_rollback ? module.dms_rollback.rollback_cluster_endpoint : null
# }
#
# output "dms_task_arn" {
#   description = "DMS replication task ARN"
#   value       = var.enable_dms_rollback ? module.dms_rollback.dms_task_arn : null
# }
#
# output "dms_instance_arn" {
#   description = "DMS replication instance ARN"
#   value       = var.enable_dms_rollback ? module.dms_rollback.dms_instance_arn : null
# }
