resource "aws_ecr_repository" "sheets" {
  name                 = "sheets"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
