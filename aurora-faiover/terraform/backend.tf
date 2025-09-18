terraform {
  backend "s3" {
    bucket = "terraform.mizzy.org"
    key    = "playground/aurora-failover/terraform.tfstate"
    region = "ap-northeast-1"
    # S3 state locking is enabled by default in Terraform 1.5+
  }
}
