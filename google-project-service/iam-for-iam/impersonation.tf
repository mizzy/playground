# Grant Service Account Token Creator role to the user for the deploy-iam service account
# This allows the user to impersonate the deploy-iam service account
resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.deploy_iam.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.user_email}"
}