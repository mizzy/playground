output "sheets_api_enabled" {
  description = "Status of Google Sheets API"
  value       = google_project_service.sheets_api.id
}