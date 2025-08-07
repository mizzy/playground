# Grant Service Account Token Creator role to the user for the deploy service account
resource "google_service_account_iam_member" "deploy_token_creator" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.user_email}"
}