terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "osaka"
  region = "ap-northeast-3"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix     = "s3-replication-test"
}

# ソースバケット A（東京）
resource "aws_s3_bucket" "source" {
  bucket        = "${local.prefix}-source-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id

  versioning_configuration {
    status = "Enabled"
  }
}

# レプリケーション先バケット B（東京）
resource "aws_s3_bucket" "destination" {
  bucket        = "${local.prefix}-destination-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "destination" {
  bucket = aws_s3_bucket.destination.id

  versioning_configuration {
    status = "Enabled"
  }
}

# レプリケーション先 B のライフサイクルルール
# レプリケーションでGLACIERに保存されたオブジェクトを90日後にDEEP_ARCHIVEへ移行
resource "aws_s3_bucket_lifecycle_configuration" "destination" {
  bucket = aws_s3_bucket.destination.id

  rule {
    id     = "glacier-to-deep-archive"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# レプリケーション先バケット C（大阪）
resource "aws_s3_bucket" "destination_osaka" {
  provider      = aws.osaka
  bucket        = "${local.prefix}-destination-osaka-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "destination_osaka" {
  provider = aws.osaka
  bucket   = aws_s3_bucket.destination_osaka.id

  versioning_configuration {
    status = "Enabled"
  }
}

# レプリケーション先 C のライフサイクルルール
resource "aws_s3_bucket_lifecycle_configuration" "destination_osaka" {
  provider = aws.osaka
  bucket   = aws_s3_bucket.destination_osaka.id

  rule {
    id     = "glacier-to-deep-archive"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# レプリケーション用IAMロール
resource "aws_iam_role" "replication" {
  name = "${local.prefix}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "${local.prefix}-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ]
        Resource = aws_s3_bucket.source.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = [
          "${aws_s3_bucket.destination.arn}/*",
          "${aws_s3_bucket.destination_osaka.arn}/*",
        ]
      },
    ]
  })
}

# レプリケーション設定（ソースバケットに設定）
# B（東京）と C（大阪）の両方に GLACIER でレプリケーション
resource "aws_s3_bucket_replication_configuration" "source" {
  depends_on = [
    aws_s3_bucket_versioning.source,
    aws_s3_bucket_versioning.destination,
    aws_s3_bucket_versioning.destination_osaka,
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.source.id

  rule {
    id       = "replicate-to-tokyo-glacier"
    status   = "Enabled"
    priority = 1

    filter {}

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "GLACIER"
    }
  }

  rule {
    id       = "replicate-to-osaka-glacier"
    status   = "Enabled"
    priority = 2

    filter {}

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.destination_osaka.arn
      storage_class = "GLACIER"
    }
  }
}
