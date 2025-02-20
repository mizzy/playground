module "vpc" {
  source = "github.com/mizzy/terraform-modules//aws/vpc"

  name       = "fluentbit-example"
  cidr_block = "10.0.0.0/16"
}
