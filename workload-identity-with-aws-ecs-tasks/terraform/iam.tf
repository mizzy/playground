resource "google_service_account" "spreadsheet_service_account" {
  account_id   = "spreadsheet-service-account"
  display_name = "spreadsheet-service-account"
}

resource "google_service_account_iam_binding" "impersonation_binding_with_data" {
  service_account_id = google_service_account.spreadsheet_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members = [
    "user:gosukenator@gmail.com",
    "serviceAccount:terraform-serviceaccount@mizzy-270104.iam.gserviceaccount.com",
  ]
}
