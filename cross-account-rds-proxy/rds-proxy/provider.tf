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

  assume_role {
    role_arn = "arn:aws:iam::000767026184:role/terraform-rds-proxy"
  }

  # RDS ProxyアカウントのアカウントIDを指定
  # 異なるアカウントにデプロイされることを防ぐ
  allowed_account_ids = [
    "000767026184",
  ]

  default_tags {
    tags = {
      project = "cross-account-rds-proxy"
      account = "rds-proxy"
    }
  }
}
