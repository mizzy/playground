resource "aws_s3_bucket" "example" {
  bucket_prefix = "dynamodb-kinesis-s3-example-"
  force_destroy = true
}
