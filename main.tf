data "archive_file" "backup_trigger_zip" {
  type        = "zip"
  source_dir  = "${path.module}/backup-trigger"
  output_path = "${path.module}/backup_trigger.zip"
}

resource "google_storage_bucket" "cloud_function_bucket" {
  name     = "cloud-function-bucket"
  project  = var.project_id
  location = var.gcp_region
}

resource "google_storage_bucket_object" "backup_trigger_zip" {
  name   = "backup_trigger.zip"
  bucket = google_storage_bucket.cloud_function_bucket.name
  source = "${path.module}/backup_trigger.zip"
}

resource "google_pubsub_topic" "function_pub_sub" {
  project = var.project_id
  name    = "my-database-backup-topic"
}

resource "google_project_iam_custom_role" "custom_role" {
  project     = var.project_id
  role_id     = "sqlBackupCreator"
  title       = "Cloud SQL Backup Creator"
  description = "Roles for cloud functions to trigger manual backups"
  permissions = ["cloudsql.backupRuns.create", "cloudsql.backupRuns.get", "cloudsql.backupRuns.list", "cloudsql.backupRuns.delete"]
}

resource "google_service_account" "backup_trigger" {
  project      = var.project_id
  account_id   = "backup-trigger-cloud-function-sa"
  display_name = "Backup Trigger cloud function service account"
}

resource "google_project_iam_member" "backup_trigger" {
  provider = google-beta
  project  = var.project_id
  member   = "serviceAccount:${google_service_account.backup_trigger.email}"
  role     = "sqlBackupCreator"
}

resource "google_cloudfunctions_function" "backup_trigger_function" {
  name                  = "backup-trigger-function"
  region                = var.gcp_region
  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.cloud_function_bucket.name
  source_archive_object = "backup_trigger.zip"
  entry_point           = "backup"
  runtime               = "nodejs8"
  project               = var.project_id
  service_account_email = google_service_account.backup_trigger.email

  environment_variables = {
    PROJECT_ID    = var.project_id
    INSTANCE_NAME = var.instance_name
  }

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "projects/${var.project_id}/topics/${google_pubsub_topic.function_pub_sub.name}"
    failure_policy {
      retry = false
    }
  }
}

resource "google_cloud_scheduler_job" "cloud_function_trigger" {
  name     = "my-cloud-function-trigger"
  schedule = "0 15 * * *"
  project  = var.project_id
  region   = var.gcp_region

  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/${google_pubsub_topic.function_pub_sub.name}"
    data       = base64encode("{}")
  }

}


