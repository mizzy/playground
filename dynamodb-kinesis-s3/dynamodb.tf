resource "aws_dynamodb_table" "example" {
  name         = "kinesis-s3-example"
  hash_key     = "Id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "Id"
    type = "S"
  }

  deletion_protection_enabled = false
}

resource "aws_dynamodb_kinesis_streaming_destination" "example" {
  table_name = aws_dynamodb_table.example.name
  stream_arn = aws_kinesis_stream.example.arn
}
