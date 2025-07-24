resource "google_iam_workload_identity_pool" "mizzy" {
  provider = google.workload-identity-pool

  workload_identity_pool_id = "mizzy-pool"
}

data "aws_caller_identity" "current" {}

resource "google_iam_workload_identity_pool_provider" "aws" {
  provider = google.workload-identity-pool

  workload_identity_pool_id          = google_iam_workload_identity_pool.mizzy.workload_identity_pool_id
  workload_identity_pool_provider_id = "mizzy-aws-provider"

  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.account"
    "attribute.aws_role"    = "assertion.arn.extract('assumed-role/{role}/')"
  }

  aws {
    account_id = data.aws_caller_identity.current.account_id
  }
}
