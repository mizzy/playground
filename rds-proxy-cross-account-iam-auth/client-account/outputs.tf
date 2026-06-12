output "vpc_id" {
  description = "クライアントアカウント側のVPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "クライアントアカウント側のVPC CIDR"
  value       = aws_vpc.this.cidr_block
}

output "ec2_role_arn" {
  description = "クライアントEC2インスタンスのIAMロールARN"
  value       = aws_iam_role.client.arn
}

output "instance_id" {
  description = "クライアントEC2インスタンスのID(SSMセッション接続に使用する)"
  value       = aws_instance.client.id
}

output "private_subnet_id" {
  description = "プライベートサブネットのID(CloudShell VPC環境の作成に使用する)"
  value       = aws_subnet.private.id
}

output "client_security_group_id" {
  description = "クライアント用セキュリティグループのID(CloudShell VPC環境の作成に使用する)"
  value       = aws_security_group.client.id
}
