# ECR Repository for bastion image
resource "aws_ecr_repository" "bastion" {
  name                 = "${var.project_name}-bastion"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_ecr_lifecycle_policy" "bastion" {
  repository = aws_ecr_repository.bastion.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
