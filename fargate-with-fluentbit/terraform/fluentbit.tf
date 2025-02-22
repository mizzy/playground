resource "aws_s3_bucket" "fluentbit" {
  bucket = "fluentbit.mizzy.org"
}

resource "aws_s3_object" "fluentbit_conf" {
  bucket = aws_s3_bucket.fluentbit.bucket
  key    = "/fluentbit.conf"
  source = "fluentbit.conf"
  etag   = filemd5("fluentbit.conf")
}
