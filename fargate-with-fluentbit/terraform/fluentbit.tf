resource "aws_s3_bucket" "fluentbit" {
  bucket = "fluentbit.mizzy.org"
}

resource "aws_s3_object" "datadog_output" {
  bucket = aws_s3_bucket.fluentbit.bucket
  key    = "/datadog-output.conf"
  source = "datadog-output.conf"
  etag   = filemd5("datadog-output.conf")
}
