terraform {
  backend "s3" {
    bucket = "terraform.mizzy.org"
    key    = "playground/cross-account-rds-proxy/rds-client/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
