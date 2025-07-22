resource "google_iam_workload_identity_pool" "mizzy" {
  workload_identity_pool_id = "mizzy-pool"
}

data "aws_caller_identity" "current" {}

resource "google_iam_workload_identity_pool_provider" "aws" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.mizzy.workload_identity_pool_id
  workload_identity_pool_provider_id = "mizzy-aws-provider"
  aws {
    account_id = data.aws_caller_identity.current.account_id
  }
}
