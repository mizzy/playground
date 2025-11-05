terraform {
  backend "s3" {
    bucket = "terraform.mizzy.org"
    key    = "playground/cross-account-rds-proxy/rds-client/iam/terraform.tfstate"
    region = "ap-northeast-1"
    # S3 state locking is enabled by default in Terraform 1.5+
  }
}
