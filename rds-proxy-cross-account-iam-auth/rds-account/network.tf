resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_subnet" "private" {
  for_each = {
    a = { az = "ap-northeast-1a", cidr = "10.0.1.0/24" }
    c = { az = "ap-northeast-1c", cidr = "10.0.2.0/24" }
  }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name}-rds-private-${each.key}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-rds-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_peering_connection" "to_client" {
  vpc_id        = aws_vpc.this.id
  peer_vpc_id   = var.client_vpc_id
  peer_owner_id = var.client_account_id
  peer_region   = "ap-northeast-1"

  tags = {
    Name = local.name
  }
}

resource "aws_route" "to_client" {
  count = var.peering_accepted ? 1 : 0

  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = var.client_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_client.id
}
