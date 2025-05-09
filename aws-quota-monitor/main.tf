module "dashboard" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/dashboard?ref=2.2"
  regions = ["ap-northeast-1"]
}

module "trusted_advisor_alarms" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/trusted_advisor_alarms?ref=2.2"
  regions = ["us-east-1"]
}

module "usage_alarms" {
  source = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/usage_alarms?ref=2.2"
}
