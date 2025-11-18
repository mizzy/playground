data "aws_caller_identity" "current" {}

resource "aws_iam_role" "terraform" {
  name = "terraform-rds-client"

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
  name   = "terraform-rds-client"
  policy = data.aws_iam_policy_document.terraform.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

data "aws_iam_policy_document" "terraform" {
  # 必要なポリシーを順次追加
  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:TagResource",
      "ecs:DescribeClusters",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeleteCluster",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:TagResource",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:DeleteLogGroup",
      "logs:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:TagRole",
      "iam:GetRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rds-client-*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:CreateTags",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:DeleteVpc",
      "ec2:CreateSubnet",
      "ec2:DescribeSubnets",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:CreateRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:CreateRoute",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeNetworkAcls",
      "ec2:CreateVpcEndpoint",
      "ec2:DescribeVpcEndpoints",
      "ec2:DeleteVpcEndpoints",
      "ec2:ModifyVpcEndpoint",
      "ec2:DescribePrefixLists",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ram:CreateResourceShare",
      "ram:AssociateResourceShare",
      "ram:DisassociateResourceShare",
      "ram:DeleteResourceShare",
      "ram:GetResourceShares",
      "ram:GetResourceShareAssociations",
      "ram:TagResource",
      "ram:ListResources",
      "ram:ListPrincipals",
      "ram:ListResourceSharePermissions",
      "ram:UpdateResourceShare",
      "ram:GetResourceShareInvitations",
      "ram:AcceptResourceShareInvitation",
      "ram:RejectResourceShareInvitation",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["ecs.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:DeleteServiceLinkedRole",
      "iam:GetServiceLinkedRoleDeletionStatus",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:StopTask",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
      "ecr:DeleteRepository",
      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",
      "ecr:TagResource",
      "ecr:ListTagsForResource",
      "ecr:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "vpc-lattice:CreateServiceNetwork",
      "vpc-lattice:GetServiceNetwork",
      "vpc-lattice:DeleteServiceNetwork",
      "vpc-lattice:TagResource",
      "vpc-lattice:ListTagsForResource",
      "vpc-lattice:UntagResource",
      "vpc-lattice:CreateServiceNetworkVpcAssociation",
      "vpc-lattice:GetServiceNetworkVpcAssociation",
      "vpc-lattice:UpdateServiceNetworkVpcAssociation",
      "vpc-lattice:DeleteServiceNetworkVpcAssociation",
      "vpc-lattice:ListServiceNetworkVpcAssociations",
      "vpc-lattice:CreateServiceNetworkResourceAssociation",
      "vpc-lattice:GetServiceNetworkResourceAssociation",
      "vpc-lattice:DeleteServiceNetworkResourceAssociation",
      "vpc-lattice:ListServiceNetworkResourceAssociations",
      "vpc-lattice:ListServiceNetworks",
      "vpc-lattice:GetResourceConfiguration",
      "vpc-lattice:CreateServiceNetworkVpcEndpointAssociation",
      "vpc-lattice:DeleteServiceNetworkVpcEndpointAssociation",
      "vpc-lattice:GetServiceNetworkVpcEndpointAssociation",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["vpc-lattice.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:CreateHostedZone",
      "route53:GetHostedZone",
      "route53:DeleteHostedZone",
      "route53:ListHostedZones",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:ChangeTagsForResource",
    ]
    resources = ["*"]
  }
}
