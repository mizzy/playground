resource "google_service_account" "spreadsheet_service_account" {
  provider = google.service-account

  account_id   = "spreadsheet-service-account"
  display_name = "spreadsheet-service-account"
}

resource "google_service_account_iam_binding" "workload_identity_user" {
  provider = google.service-account

  service_account_id = google_service_account.spreadsheet_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/attribute.aws_role/task-role",
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/attribute.aws_role/${aws_iam_role.lambda_workload_identity.name}",
  ]
}
