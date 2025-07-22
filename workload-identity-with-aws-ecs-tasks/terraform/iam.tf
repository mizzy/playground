resource "google_service_account" "spreadsheet_service_account" {
  account_id   = "spreadsheet-service-account"
  display_name = "spreadsheet-service-account"
}

data "aws_iam_role" "task_role" {
  name = "task-role"
}

resource "google_service_account_iam_binding" "workload_identity_user" {
  service_account_id = google_service_account.spreadsheet_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    // "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/attribute.aws_role/${data.aws_iam_role.task_role.name}",
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/*",
  ]
}

resource "google_service_account_iam_binding" "impersonation_binding_with_data" {
  service_account_id = google_service_account.spreadsheet_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members = [
    "user:gosukenator@gmail.com",
    "serviceAccount:terraform-serviceaccount@mizzy-270104.iam.gserviceaccount.com",
    //"principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/attribute.aws_role/${data.aws_iam_role.task_role.name}",
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.mizzy.name}/*",
  ]
}

