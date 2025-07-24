provider "google" {
  alias   = "workload-identity-pool"
  project = "workload-identity-pool-466904"
}

provider "google" {
  alias   = "service-account"
  project = "service-account-466904"
}

provider "aws" {
  allowed_account_ids = ["019115212452"]
}
