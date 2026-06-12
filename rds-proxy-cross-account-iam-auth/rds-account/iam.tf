data "aws_caller_identity" "current" {}

locals {
  proxy_resource_id = split(":", aws_db_proxy.this.arn)[6]
  db_user_arn       = "arn:aws:rds-db:ap-northeast-1:${data.aws_caller_identity.current.account_id}:dbuser:${local.proxy_resource_id}/${local.db_username}"
}

data "aws_iam_policy_document" "db_connect_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.client_account_id}:root"]
    }
  }
}

resource "aws_iam_role" "db_connect" {
  name               = "${local.name}-db-connect"
  assume_role_policy = data.aws_iam_policy_document.db_connect_assume.json
}

data "aws_iam_policy_document" "db_connect" {
  statement {
    actions   = ["rds-db:connect"]
    resources = [local.db_user_arn]
  }
}

resource "aws_iam_role_policy" "db_connect" {
  name   = "${local.name}-db-connect"
  role   = aws_iam_role.db_connect.id
  policy = data.aws_iam_policy_document.db_connect.json
}
