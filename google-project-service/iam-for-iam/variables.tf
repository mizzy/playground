variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The default region for resources"
  type        = string
  default     = "us-central1"
}

variable "user_email" {
  description = "Email of the user who needs to impersonate the service account"
  type        = string
}