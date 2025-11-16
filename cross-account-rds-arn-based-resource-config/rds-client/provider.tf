terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  allowed_account_ids = [
    "914357407416",
  ]

  default_tags {
    tags = {
      project = "cross-account-rds-arn-based"
      account = "rds-client"
    }
  }
}
