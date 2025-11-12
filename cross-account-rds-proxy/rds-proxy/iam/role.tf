data "aws_caller_identity" "current" {}

resource "aws_iam_role" "terraform" {
  name = "terraform-rds-proxy"

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
  name   = "terraform-rds-proxy"
  policy = data.aws_iam_policy_document.terraform.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

data "aws_iam_policy_document" "terraform" {
  # 必要なポリシーを順次追加
  # 最初のエラーで必要な権限のみ追加
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.current.account_id}:secret:*",
    ]
  }

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
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rds-proxy-*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:CreateTags",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeAccountAttributes",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribePrefixLists",
      "ec2:DeleteSubnet",
      "ec2:DeleteSecurityGroup",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "rds:CreateDBProxy",
      "rds:CreateDBSubnetGroup",
      "rds:AddTagsToResource",
      "rds:DescribeDBProxies",
      "rds:DescribeDBSubnetGroups",
      "rds:ListTagsForResource",
      "rds:DeleteDBProxy",
      "rds:DeleteDBSubnetGroup",
      "rds:CreateDBCluster",
      "rds:ModifyDBProxyTargetGroup",
      "rds:DescribeDBProxyTargetGroups",
      "rds:DescribeDBClusters",
      "rds:DescribeGlobalClusters",
      "rds:DeleteDBCluster",
      "rds:CreateDBInstance",
      "rds:RegisterDBProxyTargets",
      "rds:DescribeDBInstances",
      "rds:DescribeDBProxyTargets",
      "rds:DeleteDBInstance",
      "rds:DeregisterDBProxyTargets",
      "rds:CreateDBProxyEndpoint",
      "rds:DescribeDBProxyEndpoints",
      "rds:ModifyDBProxyEndpoint",
      "rds:DeleteDBProxyEndpoint",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServiceLinkedRoleDeletionStatus",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["rds.amazonaws.com", "vpc-lattice.amazonaws.com", "elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "vpc-lattice:CreateResourceGateway",
      "vpc-lattice:GetResourceGateway",
      "vpc-lattice:DeleteResourceGateway",
      "vpc-lattice:TagResource",
      "vpc-lattice:ListTagsForResource",
      "vpc-lattice:UntagResource",
      "vpc-lattice:CreateResourceConfiguration",
      "vpc-lattice:GetResourceConfiguration",
      "vpc-lattice:DeleteResourceConfiguration",
      "vpc-lattice:ListResourceConfigurations",
      "vpc-lattice:ListResourceGateways",
      "vpc-lattice:PutResourcePolicy",
      "vpc-lattice:GetResourcePolicy",
      "vpc-lattice:DeleteResourcePolicy",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ram:CreateResourceShare",
      "ram:GetResourceShares",
      "ram:DeleteResourceShare",
      "ram:UpdateResourceShare",
      "ram:AssociateResourceShare",
      "ram:DisassociateResourceShare",
      "ram:GetResourceShareAssociations",
      "ram:TagResource",
      "ram:ListResources",
      "ram:ListResourceSharePermissions",
    ]
    resources = ["*"]
  }

  # RDS Proxy permissions
  statement {
    effect = "Allow"
    actions = [
      "rds:CreateDBProxy",
      "rds:DescribeDBProxies",
      "rds:DeleteDBProxy",
      "rds:ModifyDBProxy",
      "rds:AddTagsToResource",
      "rds:ListTagsForResource",
      "rds:RemoveTagsFromResource",
      "rds:CreateDBProxyEndpoint",
      "rds:DescribeDBProxyEndpoints",
      "rds:DeleteDBProxyEndpoint",
      "rds:ModifyDBProxyEndpoint",
      "rds:RegisterDBProxyTargets",
      "rds:DeregisterDBProxyTargets",
      "rds:DescribeDBProxyTargets",
      "rds:DescribeDBProxyTargetGroups",
      "rds:ModifyDBProxyTargetGroup",
    ]
    resources = ["*"]
  }

  # Elastic Load Balancing permissions for NLB
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = ["*"]
  }

  # VPC Endpoint Service permissions
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVpcEndpointServiceConfiguration",
      "ec2:DescribeVpcEndpointServiceConfigurations",
      "ec2:DeleteVpcEndpointServiceConfigurations",
      "ec2:ModifyVpcEndpointServiceConfiguration",
      "ec2:ModifyVpcEndpointServicePermissions",
      "ec2:DescribeVpcEndpointServicePermissions",
      "ec2:DescribeVpcEndpointConnections",
      "ec2:AcceptVpcEndpointConnections",
      "ec2:RejectVpcEndpointConnections",
    ]
    resources = ["*"]
  }

  # IAM PassRole for RDS Proxy
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rds-proxy-role",
    ]
  }
}
