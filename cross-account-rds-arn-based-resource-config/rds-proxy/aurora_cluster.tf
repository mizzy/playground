# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "rds-proxy-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  tags = {
    Name = "rds-proxy-subnet-group"
  }
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "aurora-cluster-arn-based"
  engine                  = "aurora-postgresql"
  engine_version          = "15.10"
  database_name           = "testdb"
  master_username         = "postgres"
  master_password         = "password123"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 1

  tags = {
    Name = "aurora-cluster-arn-based"
  }
}

# Aurora Writer Instance
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "aurora-instance-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = "15.10"

  tags = {
    Name = "aurora-instance-writer"
  }
}
