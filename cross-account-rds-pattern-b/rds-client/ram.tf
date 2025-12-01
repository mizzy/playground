# Accept RAM Resource Share from rds-proxy account
resource "aws_ram_resource_share_accepter" "resource_config" {
  share_arn = var.resource_share_arn
}
