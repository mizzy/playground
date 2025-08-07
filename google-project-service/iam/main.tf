# Create the deploy service account for general deployment tasks
resource "google_service_account" "deploy" {
  account_id   = "deploy"
  display_name = "Deploy Service Account"
  description  = "Service account for general deployment tasks via Terraform"
}

# Create custom role with all necessary permissions for Service Usage API management
resource "google_project_iam_custom_role" "terraform_service_manager" {
  role_id     = "terraformServiceManager"
  title       = "Terraform Service Manager"
  description = "Permissions for managing Google Cloud services via Terraform"
  permissions = [
    # Read permissions for state management
    "serviceusage.services.get",
    "serviceusage.services.list",
    "serviceusage.operations.get",
    "serviceusage.operations.list",
    # Write permissions for service management
    "serviceusage.services.enable",
    "serviceusage.services.disable",
    # Project metadata needed by Terraform provider
    "resourcemanager.projects.get",
  ]
}

# Grant the custom role to the deploy service account
resource "google_project_iam_member" "deploy_service_manager" {
  project = var.project_id
  role    = google_project_iam_custom_role.terraform_service_manager.id
  member  = "serviceAccount:${google_service_account.deploy.email}"
}