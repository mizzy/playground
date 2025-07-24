resource "google_project_service" "iamcredentials" {
  provider = google.workload-identity-pool

  service = "iamcredentials.googleapis.com"
}


resource "google_project_service" "spreadsheet_service" {
  provider = google.service-account

  service = "sheets.googleapis.com"
}
