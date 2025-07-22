resource "google_service_account" "spreadsheet_service_account" {
  account_id   = "spreadsheet-service-account"
  display_name = "spreadsheet-service-account"
}

resource "google_project_iam_member" "service_account_token_creator" {
  project = data.google_project.current.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "user:gosukenator@gmail.com"
}

resource "google_service_account_iam_member" "impersonation_binding_with_data" {
  service_account_id = google_service_account.spreadsheet_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:gosukenator@gmail.com"
}
