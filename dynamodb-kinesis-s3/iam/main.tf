data "aws_iam_role" "terraform" {
  name = "terraform"
}

resource "aws_iam_role_policy" "dynamodb_kinesis_s3" {
  name   = "dynamodb-kinesis-s3"
  role   = data.aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.dynamodb_kinesis_s3.json
}

data "aws_iam_policy_document" "dynamodb_kinesis_s3" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
      "dynamodb:DescribeKinesisStreamingDestination",
      "dynamodb:EnableKinesisStreamingDestination",
      "dynamodb:DisableKinesisStreamingDestination",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
    ]

    resources = ["arn:aws:dynamodb:ap-northeast-1:019115212452:table/kinesis-s3-example"]
  }

  statement {
    effect = "Allow"

    actions = [
      "kinesis:CreateStream",
      "kinesis:DeleteStream",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListTagsForStream",
      "kinesis:AddTagsToStream",
      "kinesis:RemoveTagsFromStream",
      "kinesis:IncreaseStreamRetentionPeriod",
      "kinesis:DecreaseStreamRetentionPeriod",
      "kinesis:UpdateShardCount",
      "kinesis:PutRecord",
      "kinesis:PutRecords",
    ]

    resources = ["arn:aws:kinesis:ap-northeast-1:019115212452:stream/dynamodb-kinesis-s3-example"]
  }

  statement {
    effect = "Allow"

    actions = [
      "firehose:CreateDeliveryStream",
      "firehose:DeleteDeliveryStream",
      "firehose:DescribeDeliveryStream",
      "firehose:UpdateDestination",
      "firehose:TagDeliveryStream",
      "firehose:UntagDeliveryStream",
      "firehose:ListTagsForDeliveryStream",
    ]

    resources = ["arn:aws:firehose:ap-northeast-1:019115212452:deliverystream/dynamodb-kinesis-s3-example"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketWebsite",
      "s3:GetBucketVersioning",
      "s3:GetBucketLogging",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketTagging",
      "s3:GetAccelerateConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:PutBucketTagging",
      "s3:PutBucketPolicy",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:ListBucketVersions",
    ]

    resources = [
      "arn:aws:s3:::dynamodb-kinesis-s3-example-*",
      "arn:aws:s3:::dynamodb-kinesis-s3-example-*/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
    ]

    resources = ["arn:aws:iam::019115212452:role/dynamodb-kinesis-s3-firehose"]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["dynamodb.amazonaws.com"]
    }
  }
}
