# AWS Resource Access Manager (RAM) Resource Share
# Share the private subnets with rds-proxy account
resource "aws_ram_resource_share" "subnets" {
  name                      = "rds-client-subnets-share"
  allow_external_principals = true

  tags = {
    Name = "rds-client-subnets-share"
  }
}

# Associate subnets with the resource share
resource "aws_ram_resource_association" "subnet_a" {
  resource_arn       = aws_subnet.private_a.arn
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

resource "aws_ram_resource_association" "subnet_c" {
  resource_arn       = aws_subnet.private_c.arn
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

# Share with rds-proxy account
resource "aws_ram_principal_association" "rds_proxy_account" {
  principal          = "000767026184"
  resource_share_arn = aws_ram_resource_share.subnets.arn
}
