module "vpc" {
  source = "git::https://github.com/mizzy/terraform-modules.git//aws/vpc?ref=main"

  name       = var.name_prefix
  cidr_block = var.vpc_cidr
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.id
}

output "public_subnets" {
  description = "Public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnets"
  value       = module.vpc.private_subnets
}