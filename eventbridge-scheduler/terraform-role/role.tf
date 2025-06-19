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
  policy = data.aws_iam_policy_document.terraform.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

data "aws_iam_policy_document" "terraform" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:TagRole",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:PassRole",
    ]

    resources = ["arn:aws:iam::019115212452:role/scheduler"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:TagPolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:DeletePolicy",
    ]

    resources = [
      "arn:aws:iam::019115212452:policy/scheduler-policy",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:GetSchedule",
      "scheduler:DeleteSchedule",
      "scheduler:UpdateSchedule",
    ]
    resources = ["arn:aws:scheduler:ap-northeast-1:019115212452:schedule/default/ecs-task-schedule"]
  }
}
