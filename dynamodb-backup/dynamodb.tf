resource "aws_dynamodb_table" "user" {
  name         = "User"
  hash_key     = "UserId"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "UserName"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  global_secondary_index {
    hash_key        = "UserName"
    name            = "UserNameIndex"
    projection_type = "ALL"
  }

  deletion_protection_enabled = true
}
