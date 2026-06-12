data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "client" {
  name               = "${local.name}-client"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.client.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "db_connect_direct" {
  count = var.rds_proxy_resource_id == null ? 0 : 1

  name = "${local.name}-db-connect-direct"
  role = aws_iam_role.client.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "rds-db:connect"
        Resource = concat(
          ["arn:aws:rds-db:ap-northeast-1:${var.rds_account_id}:dbuser:${var.rds_proxy_resource_id}/${var.db_username}"],
          var.rds_db_resource_id == null ? [] : ["arn:aws:rds-db:ap-northeast-1:${var.rds_account_id}:dbuser:${var.rds_db_resource_id}/${var.iam_db_username}"]
        )
      }
    ]
  })
}

resource "aws_iam_role_policy" "assume_db_connect_role" {
  count = var.db_connect_role_arn == null ? 0 : 1

  name = "${local.name}-assume-db-connect-role"
  role = aws_iam_role.client.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.db_connect_role_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "client" {
  name = "${local.name}-client"
  role = aws_iam_role.client.name
}
