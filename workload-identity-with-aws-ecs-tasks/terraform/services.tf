resource "google_project_service" "spreadsheet_service" {
  service = "sheets.googleapis.com"
}

resource "google_project_service" "iamcredentials" {
  service = "iamcredentials.googleapis.com"
}
