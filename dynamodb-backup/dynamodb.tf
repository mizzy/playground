resource "aws_dynamodb_table" "user" {
  name         = "User"
  hash_key     = "UserId"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "UserName"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  global_secondary_index {
    hash_key        = "UserName"
    name            = "UserNameIndex"
    projection_type = "ALL"
  }

  deletion_protection_enabled = true
}

resource "aws_backup_vault" "dynamodb" {
  name          = "dynamodb-backup-vault"
  force_destroy = true
}

resource "aws_backup_plan" "dynamodb" {
  name = "dynamodb-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.dynamodb.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_selection" "dynamodb" {
  name         = "dynamodb-backup-selection"
  iam_role_arn = "arn:aws:iam::019115212452:role/service-role/AWSBackupDefaultServiceRole"
  plan_id      = aws_backup_plan.dynamodb.id

  resources = [
    aws_dynamodb_table.user.arn
  ]
}
