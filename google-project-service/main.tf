resource "google_project_service" "sheets_api" {
  project = var.project_id
  service = "sheets.googleapis.com"
  
  disable_on_destroy = true
}
