# RAM Resource Share for Resource Configuration
resource "aws_ram_resource_share" "resource_config" {
  name                      = "pattern-b-resource-share"
  allow_external_principals = true

  tags = {
    Name = "pattern-b-resource-share"
  }
}

# Associate Resource Configuration with RAM
resource "aws_ram_resource_association" "rds_cluster" {
  resource_arn       = aws_vpclattice_resource_configuration.rds_cluster.arn
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}

# Share with rds-client account
resource "aws_ram_principal_association" "rds_client" {
  principal          = "914357407416"
  resource_share_arn = aws_ram_resource_share.resource_config.arn
}
