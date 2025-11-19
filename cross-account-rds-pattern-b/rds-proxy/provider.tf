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
  region = "ap-northeast-1"

  allowed_account_ids = [
    "000767026184",
  ]

  default_tags {
    tags = {
      project = "cross-account-rds-pattern-b"
      account = "rds-proxy"
    }
  }
}
