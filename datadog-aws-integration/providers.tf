terraform {
  required_providers {
    datadog = {
      source = "datadog/datadog"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "datadog" {
  api_url  = "https://api.ap1.datadoghq.com"
  validate = false
}

provider "aws" {
  region = "ap-northeast-1"
}
