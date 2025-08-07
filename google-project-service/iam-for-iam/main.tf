# IAM for IAM: Manage permissions for IAM management
# This configuration grants the necessary permissions to manage IAM roles and policies

# Create the deploy-iam service account for IAM management
resource "google_service_account" "deploy_iam" {
  account_id   = "deploy-iam"
  display_name = "Deploy IAM Service Account"
  description  = "Service account for managing IAM resources via Terraform"
}

# Create a custom role for IAM management
resource "google_project_iam_custom_role" "iam_manager" {
  role_id     = "iamManager"
  title       = "IAM Manager"
  description = "Permissions to manage IAM roles, policies, and service accounts"
  permissions = [
    # Custom role management (needed for terraform_service_manager role)
    "iam.roles.create",
    "iam.roles.delete",
    "iam.roles.get",
    "iam.roles.update",
    "iam.roles.undelete",
    
    # Project IAM policy management (needed for granting roles)
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
    
    # Service account management (needed for creating and destroying deploy service account)
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.get",
    
    # Service account IAM policy (needed for impersonation setup)
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
    
    # Project metadata (needed by Terraform provider)
    "resourcemanager.projects.get",
  ]
}

# Grant the IAM manager role to the deploy-iam service account
resource "google_project_iam_member" "deploy_iam_manager" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_manager.id
  member  = "serviceAccount:${google_service_account.deploy_iam.email}"
}