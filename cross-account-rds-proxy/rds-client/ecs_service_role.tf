# ECS Service Linked Role
# This is automatically created when first needed, but we create it explicitly
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}
