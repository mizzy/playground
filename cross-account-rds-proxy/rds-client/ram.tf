# Accept Resource Configuration share from rds-proxy account
resource "aws_ram_resource_share_accepter" "aurora_config" {
  share_arn = "arn:aws:ram:ap-northeast-1:000767026184:resource-share/d4598dbc-1824-4185-b80a-5f9632ce5831"
}
