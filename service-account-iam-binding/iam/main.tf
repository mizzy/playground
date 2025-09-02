terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

resource "google_service_account" "terraform_deployer" {
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployer Service Account"
  description  = "Service account for deploying Terraform resources"
}

resource "google_project_iam_custom_role" "terraform_deployer_role" {
  role_id     = "terraformDeployer"
  title       = "Terraform Deployer"
  description = "Custom role for Terraform deployment with minimal permissions"

  permissions = [
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.list",
    "iam.serviceAccounts.update",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy"
  ]
}

resource "google_project_iam_member" "terraform_deployer_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.terraform_deployer_role.id
  member  = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

output "service_account_email" {
  description = "Email of the Terraform deployer service account"
  value       = google_service_account.terraform_deployer.email
}

resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.terraform_deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:gosukenator@gmail.com"
}

output "custom_role_id" {
  description = "ID of the custom role"
  value       = google_project_iam_custom_role.terraform_deployer_role.id
}
