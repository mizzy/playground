# ECR Repository for postgres client
resource "aws_ecr_repository" "postgres_client" {
  name                 = "postgres-client"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # For easier cleanup

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "postgres-client"
  }
}

output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = aws_ecr_repository.postgres_client.repository_url
}
