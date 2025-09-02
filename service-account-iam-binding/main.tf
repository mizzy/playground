resource "google_service_account" "example" {
  account_id   = "example-service-account"
  display_name = "Example Service Account"
  description  = "Example service account for IAM binding demonstration"
}

resource "google_service_account_iam_binding" "token_creator" {
  service_account_id = google_service_account.example.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "user:gosukenator@gmail.com",
  ]
}

resource "google_service_account_iam_binding" "user" {
  service_account_id = google_service_account.example.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    "user:gosukenator@gmail.com",
  ]
}

resource "google_service_account_iam_binding" "impersonator" {
  service_account_id = google_service_account.example.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:terraform-deployer@${var.project_id}.iam.gserviceaccount.com",
  ]
}
