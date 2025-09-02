provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = "terraform-deployer@${var.project_id}.iam.gserviceaccount.com"
}
