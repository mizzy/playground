resource "aws_vpc" "this" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-client"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = "ap-northeast-1a"
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-client-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.1.2.0/24"

  tags = {
    Name = "${local.name}-client-private"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name}-client-nat"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${local.name}-client"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-client"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-client-public"
  }
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-client-private"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_peering_connection_accepter" "from_rds" {
  count = var.peering_connection_id == null ? 0 : 1

  vpc_peering_connection_id = var.peering_connection_id
  auto_accept               = true

  tags = {
    Name = local.name
  }
}

resource "aws_route" "to_rds" {
  count = var.peering_connection_id == null ? 0 : 1

  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = var.rds_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.from_rds[0].vpc_peering_connection_id
}
