resource "aws_security_group" "rds_proxy" {
  name   = "${local.name}-rds-proxy"
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-rds-proxy"
  }
}

resource "aws_vpc_security_group_ingress_rule" "proxy_from_client_vpc" {
  security_group_id = aws_security_group.rds_proxy.id
  cidr_ipv4         = var.client_vpc_cidr
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "proxy_to_rds" {
  security_group_id            = aws_security_group.rds_proxy.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

data "aws_iam_policy_document" "rds_proxy_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_proxy" {
  name               = "${local.name}-rds-proxy"
  assume_role_policy = data.aws_iam_policy_document.rds_proxy_assume.json
}

data "aws_iam_policy_document" "rds_proxy" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.this.master_user_secret[0].secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.ap-northeast-1.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "rds_proxy" {
  name   = "${local.name}-rds-proxy"
  role   = aws_iam_role.rds_proxy.id
  policy = data.aws_iam_policy_document.rds_proxy.json
}

resource "aws_db_proxy" "this" {
  name                   = local.name
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_subnet_ids         = [for s in aws_subnet.private : s.id]
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  require_tls            = true

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_db_instance.this.master_user_secret[0].secret_arn
  }
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
}

resource "aws_db_proxy_target" "this" {
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
  db_instance_identifier = aws_db_instance.this.identifier
}
