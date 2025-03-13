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
      "arn:aws:dynamodb:ap-northeast-1:${data.aws_caller_identity.current.account_id}:table/User",
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
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dynamodb-backup-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSBackupDefaultServiceRole",
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
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/dynamodb-backup-role-policy",
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
      "backup:UntagResource",
      # for destroy
      "backup:ListRecoveryPointsByBackupVault",
      "backup:DeleteBackupVault",
    ]
    resources = [
      "arn:aws:backup:ap-northeast-1:${data.aws_caller_identity.current.account_id}:backup-vault:dynamodb-backup-vault",
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
      "backup:UntagResource",
      # for plan
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
      "backup:ListTags",
      # for destroy
      "backup:DeleteBackupPlan",
      "backup:DeleteBackupSelection",
      "backup:UpdateBackupPlan",
    ]
    resources = [
      "arn:aws:backup:ap-northeast-1:${data.aws_caller_identity.current.account_id}:backup-plan:*",
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

    condition {
      test     = "StringLike"
      variable = "kms:RequestAlias"
      values   = ["alias/aws/backup"]
    }

    resources = ["arn:aws:kms:ap-northeast-1:${data.aws_caller_identity.current.account_id}:key/*"]
    #resources = ["arn:aws:kms:ap-northeast-1:data.aws_caller_identity.current.account_id:key/5efb1276-a848-4010-83d6-ee2adad51564"]
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
