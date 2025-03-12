resource "aws_backup_vault" "dynamodb" {
  name          = "dynamodb-backup-vault"
  force_destroy = true
}

resource "aws_backup_plan" "dynamodb" {
  name = "dynamodb-backup-plan"

  rule {
    rule_name                    = "hourly-backup"
    target_vault_name            = aws_backup_vault.dynamodb.name
    schedule                     = "cron(0 * * * ? *)"
    schedule_expression_timezone = "Asia/Tokyo"
    enable_continuous_backup     = true

    lifecycle {
      delete_after = 30
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
      "dynamodb:CreateBackup",
      "dynamodb:StartAwsBackupJob",
      "dynamodb:ListTagsOfResource",
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
    sid    = "BackupVaultPermissions"
    effect = "Allow"
    actions = [
      "backup:DescribeBackupVault",
      "backup:CopyIntoBackupVault",
    ]
    resources = [aws_backup_vault.dynamodb.arn]
  }
}

resource "aws_iam_policy" "dynamodb_backup_role_policy" {
  name   = "dynamodb-backup-role-policy"
  policy = data.aws_iam_policy_document.dynamodb_backup_role_policy.json
}

resource "aws_iam_role_policy_attachment" "dynamic_backup_role" {
  role       = aws_iam_role.dynamodb_backup_role.name
  policy_arn = aws_iam_policy.dynamodb_backup_role_policy.arn
}
