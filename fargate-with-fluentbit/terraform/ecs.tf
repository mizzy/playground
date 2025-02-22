resource "aws_ecs_cluster" "example" {
  name = "example"
}

resource "aws_iam_role" "task_role" {
  name               = "task-role"
  assume_role_policy = data.aws_iam_policy_document.task_role_assume_role.json
}

data "aws_iam_policy_document" "task_role_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:*"]
    resources = [aws_ssm_parameter.datadog_api_key.arn]
  }
}

resource "aws_iam_policy" "ssm" {
  name   = "ssm"
  policy = data.aws_iam_policy_document.ssm.json
}

resource "aws_iam_role_policy_attachment" "task_role" {
  policy_arn = aws_iam_policy.ssm.arn
  role       = aws_iam_role.task_role.name
}
