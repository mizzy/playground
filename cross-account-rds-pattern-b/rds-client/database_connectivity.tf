# データベース接続に必要なリソース（VPC Lattice Service Network経由）

# Security Group for Database Endpoints
resource "aws_security_group" "database" {
  name        = "pattern-b-database-sg"
  description = "Security group for database endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "pattern-b-database-sg"
  }
}
