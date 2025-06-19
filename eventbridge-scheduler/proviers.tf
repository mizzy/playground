provider "aws" {
  region = "ap-northeast-1"

  assume_role {
    role_arn = "arn:aws:iam::019115212452:role/terraform"
  }

  default_tags {
    tags = {
      project = "mizzy"
    }
  }
}
