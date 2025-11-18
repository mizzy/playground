terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "ap-northeast-1"
  allowed_account_ids = ["914357407416"]
  assume_role {
    role_arn = "arn:aws:iam::914357407416:role/terraform-rds-client"
  }
  default_tags {
    tags = {
      project = "cross-account-rds-pattern-a"
      account = "rds-client"
    }
  }
}
