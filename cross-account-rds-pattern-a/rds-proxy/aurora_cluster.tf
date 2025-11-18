# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "pattern-a-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  tags = {
    Name = "pattern-a-subnet-group"
  }
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "pattern-a-aurora-cluster"
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
    Name = "pattern-a-aurora-cluster"
  }
}

# Aurora Writer Instance
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "pattern-a-aurora-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = "15.10"

  tags = {
    Name = "pattern-a-aurora-writer"
  }
}
