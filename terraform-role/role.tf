data "aws_caller_identity" "current" {}

resource "aws_iam_role" "terraform" {
  name = "terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "terraform" {
  name   = "terraform"
  policy = data.aws_iam_policy_document.terraform.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn

}

data "aws_iam_policy_document" "terraform" {
  # DynamoDB
  statement {
    effect = "Allow"
    actions = [
      # for apply
      "dynamodb:CreateTable",
      "dynamodb:TagResource",
      "dynamodb:UpdateContinuousBackups",
      # for plan
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      # for destroy
      "dynamodb:DeleteTable",
    ]

    resources = [
      "arn:aws:dynamodb:ap-northeast-1:019115212452:table/User",
    ]
  }

  # IAM Role
  statement {
    effect = "Allow"
    actions = [
      # for apply
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:TagRole",
      "iam:PassRole",
      # for plan
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      # for destroy
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [
      "arn:aws:iam::019115212452:role/dynamodb-backup-role",
    ]
  }

  # IAM Policy
  statement {
    effect = "Allow"
    actions = [
      # for apply
      "iam:CreatePolicy",
      "iam:TagPolicy",
      # for plan
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      # for destroy
      "iam:DeletePolicy",
      "iam:ListPolicyVersions",
    ]
    resources = [
      "arn:aws:iam::019115212452:policy/dynamodb-backup-role-policy",
    ]
  }

  # Backup Vault
  statement {
    effect = "Allow"
    actions = [
      # for plan
      "backup:DescribeBackupVault",
      "backup:ListTags",
      # for apply
      "backup:CreateBackupVault",
      "backup:TagResource",
      # for destroy
      "backup:ListRecoveryPointsByBackupVault",
      "backup:DeleteBackupVault",
    ]
    resources = [
      "arn:aws:backup:ap-northeast-1:019115212452:backup-vault:dynamodb-backup-vault",
    ]
  }

  # Backup Plan
  statement {
    effect = "Allow"
    actions = [
      # for apply
      "backup:CreateBackupPlan",
      "backup:CreateBackupSelection",
      "backup:TagResource",
      # for plan
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
      "backup:ListTags",
      # for destroy
      "backup:DeleteBackupPlan",
      "backup:DeleteBackupSelection",
    ]
    resources = [
      "arn:aws:backup:ap-northeast-1:019115212452:backup-plan:*",
    ]
  }

  # KMS
  # Ref https://docs.aws.amazon.com/aws-backup/latest/devguide/create-a-vault.html
  statement {
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:RetireGrant",
    ]
    resources = ["*"]
    # resources = ["arn:aws:backup:ap-northeast-1:019115212452:key/*"]
  }

  # Ref https://docs.aws.amazon.com/aws-backup/latest/devguide/create-a-vault.html
  statement {
    effect = "Allow"
    actions = [
      "backup-storage:MountCapsule",
    ]
    resources = ["*"]
  }
}
