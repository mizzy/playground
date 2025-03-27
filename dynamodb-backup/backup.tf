resource "aws_backup_vault" "dynamodb" {
  name = "dynamodb-backup-vault"

  force_destroy = true
}

resource "aws_backup_vault" "copy" {
  name          = "dynamodb-backup-vault"
  provider      = aws.osaka
  force_destroy = true
}

resource "aws_backup_vault_lock_configuration" "dynamodb" {
  backup_vault_name = aws_backup_vault.dynamodb.name
}

resource "aws_backup_plan" "dynamodb" {
  name = "dynamodb-backup-plan"

  rule {
    rule_name                    = "hourly-backup"
    target_vault_name            = aws_backup_vault.dynamodb.name
    schedule                     = "cron(0 * * * ? *)"
    schedule_expression_timezone = "Asia/Tokyo"
    #enable_continuous_backup     = true # default false

    #lifecycle {
    #cold_storage_after = null
    #delete_after       = null
    #}

    copy_action {
      destination_vault_arn = aws_backup_vault.copy.arn
    }
  }
}

resource "aws_backup_selection" "dynamodb" {
  name         = "dynamodb-backup-selection"
  iam_role_arn = aws_iam_role.dynamodb_backup_role.arn
  plan_id      = aws_backup_plan.dynamodb.id

  resources = [
    aws_dynamodb_table.user.arn
  ]
}

resource "aws_iam_role" "dynamodb_backup_role" {
  name = "dynamodb-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "backup.amazonaws.com"
        },
      }
    ]
  })
}

data "aws_iam_policy_document" "dynamodb_backup_role_policy" {
  statement {
    sid    = "DynamoDBPermissions"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      # "dynamodb:CreateBackup",
      "dynamodb:StartAwsBackupJob",
      "dynamodb:ListTagsOfResource",
      "dynamodb:RestoreTableFromAwsBackup",
    ]
    resources = [
      aws_dynamodb_table.user.arn,
    ]
  }

  statement {
    sid    = "DynamoDBBackupResourcePermissions"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeBackup",
      "dynamodb:DeleteBackup",
    ]
    resources = [
      "${aws_dynamodb_table.user.arn}/backup/*",
    ]
  }

  statement {
    sid = "BackupVaultCopyPermissions"
    actions = [
      "backup:CopyIntoBackupVault",
    ]
    resources = [aws_backup_vault.copy.arn]
  }
}

/*
data "aws_iam_policy_document" "backup" {
  statement {
    sid    = "BackupVaultPermissions"
    effect = "Allow"
    actions = [
      "backup:DescribeBackupVault",
    ]
    resources = [aws_backup_vault.dynamodb.arn]
  }

  statement {
    sid = "BackupVaultCopyPermissions"
    actions = [
      "backup:CopyIntoBackupVault",
    ]
    resources = [aws_backup_vault.copy.arn]
  }
}
*/

resource "aws_iam_role_policy" "dynamodb_backup_role_policy" {
  name   = "dynamodb-backup-role-policy"
  role   = aws_iam_role.dynamodb_backup_role.name
  policy = data.aws_iam_policy_document.dynamodb_backup_role_policy.json
}

/*
resource "aws_iam_role_policy" "backup" {
  name   = "backup"
  policy = data.aws_iam_policy_document.backup.json
  role   = aws_iam_role.dynamodb_backup_role.name
}
*/
