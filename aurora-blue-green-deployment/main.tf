terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "git::https://github.com/mizzy/terraform-modules.git//aws/vpc?ref=main"
  
  name       = var.name_prefix
  cidr_block = var.vpc_cidr
}

# Aurora Module
module "aurora" {
  source = "./modules/aurora"

  name_prefix                  = var.name_prefix
  vpc_id                       = module.vpc.id
  vpc_cidr                     = var.vpc_cidr
  subnet_ids                   = [for s in module.vpc.private_subnets : s.id]
  engine_version               = var.aurora_engine_version
  instance_count               = var.aurora_instance_count
  instance_class               = var.instance_class
  master_username              = var.master_username
  master_password              = var.master_password
  database_name                = var.database_name
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  maintenance_window           = var.maintenance_window
  skip_final_snapshot          = var.skip_final_snapshot
  enable_enhanced_monitoring   = var.enable_enhanced_monitoring
  monitoring_interval          = var.monitoring_interval
  performance_insights_enabled = var.performance_insights_enabled
  tags                         = var.tags
}

