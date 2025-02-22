resource "aws_kms_key" "datadog" {}

resource "aws_kms_alias" "datadog" {
  name          = "alias/datadog"
  target_key_id = aws_kms_key.datadog.id
}

data "aws_kms_secrets" "datadog" {
  secret {
    name    = "api-key"
    payload = "AQICAHgJlo4J0kaIE5OgiI8JGp+qNuTdj/xLvbAg0sRlvX2XtQEkgYzlYAlBiD/XjGG3Iwl7AAAAfjB8BgkqhkiG9w0BBwagbzBtAgEAMGgGCSqGSIb3DQEHATAeBglghkgBZQMEAS4wEQQMDHaysRE0GNDAmeWuAgEQgDu0EG0p9au8s85SJVQFiTnekJy6zPRXGDQVQCW0Zdwi63USc+sky/Zc9aW/+N6fNGE39kSBFecC4qWxoA=="
  }
}

resource "aws_ssm_parameter" "datadog_api_key" {
  name  = "/dev/datadog_api_key"
  type  = "SecureString"
  value = data.aws_kms_secrets.datadog.plaintext["api-key"]
}
