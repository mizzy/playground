# 条件付きIAMの実用例

# 1. Compute Engineの開発環境のみ管理可能
resource "google_project_iam_member" "compute_dev_only" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "Dev instances only"
    description = "Can only manage instances with dev- prefix"
    expression  = <<-EOT
      resource.name.startsWith('projects/${var.project_id}/zones/') &&
      resource.name.contains('/instances/dev-')
    EOT
  }
}

# 2. 特定のCloud Storageバケットのみアクセス可能
resource "google_project_iam_member" "storage_specific_bucket" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "App bucket only"
    description = "Can only access app-data bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/app-data')"
  }
}

# 3. 営業時間内のみCloud SQL管理可能
resource "google_project_iam_member" "sql_business_hours" {
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "Business hours only"
    description = "Can only manage SQL during business hours"
    expression  = <<-EOT
      request.time.getHours('Asia/Tokyo') >= 9 &&
      request.time.getHours('Asia/Tokyo') <= 18 &&
      request.time.getDayOfWeek('Asia/Tokyo') >= 1 &&
      request.time.getDayOfWeek('Asia/Tokyo') <= 5
    EOT
  }
}

# 4. 特定のラベルを持つリソースのみ
resource "google_project_iam_member" "labeled_resources_only" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "Terraform managed only"
    description = "Can only manage resources with managed-by=terraform label"
    expression  = "resource.labels.managed_by == 'terraform'"
  }
}

# 5. 特定のSecret Managerシークレットのみ
resource "google_project_iam_member" "secrets_app_only" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "App secrets only"
    description = "Can only access secrets with app- prefix"
    expression  = <<-EOT
      resource.name.startsWith('projects/${var.project_id}/secrets/app-')
    EOT
  }
}

# 6. BigQueryの特定データセットのみ
resource "google_project_iam_member" "bigquery_analytics_only" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:deploy@${var.project_id}.iam.gserviceaccount.com"
  
  condition {
    title       = "Analytics dataset only"
    description = "Can only access analytics dataset"
    expression  = <<-EOT
      resource.type == 'bigquery.googleapis.com/Dataset' &&
      resource.name == 'projects/${var.project_id}/datasets/analytics'
    EOT
  }
}