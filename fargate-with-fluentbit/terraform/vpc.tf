resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c"
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1c"
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_eip" "private_a" {
  domain = "vpc"
}

resource "aws_eip" "private_c" {
  domain = "vpc"
}

resource "aws_nat_gateway" "private_a" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.private_a.id
}

resource "aws_nat_gateway" "private_c" {
  subnet_id     = aws_subnet.public_c.id
  allocation_id = aws_eip.private_c.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "internet" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
}

resource "aws_route" "nat_for_a" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_a.id
  nat_gateway_id         = aws_nat_gateway.private_a.id
}

resource "aws_route" "nat_for_c" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_c.id
  nat_gateway_id         = aws_nat_gateway.private_c.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}
