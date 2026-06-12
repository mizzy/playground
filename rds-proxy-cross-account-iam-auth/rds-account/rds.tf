resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_security_group" "rds" {
  name   = "${local.name}-rds"
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_proxy" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.rds_proxy.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_instance" "this" {
  identifier     = local.name
  engine         = "postgres"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name                     = "appdb"
  username                    = local.db_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
}
