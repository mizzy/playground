# Private Hosted Zones for DNS-based Resource Endpoints
#
# DNS-based Resource Configurations do not create Private Hosted Zones automatically.
# We need to manually create PHZs and A records pointing to the Resource Endpoint IPs.
#
# WARNING: Resource Endpoint IPs may change. If connectivity fails, check and update these IPs.

# Get VPC ID for PHZ association
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["pattern-a-vpc"]
  }
}

# Private Hosted Zone for RDS Proxy (proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com)
resource "aws_route53_zone" "rds_proxy" {
  name = "proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"

  vpc {
    vpc_id = data.aws_vpc.main.id
  }

  tags = {
    Name        = "pattern-a-rds-proxy-phz"
    Description = "Private Hosted Zone for RDS Proxy DNS-based Resource Endpoints"
  }
}

# A record for RDS Proxy Writer endpoint
resource "aws_route53_record" "rds_proxy_writer" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy"
  type    = "A"
  ttl     = 60

  # Resource Endpoint IPs for RDS Proxy Writer
  # NOTE: These IPs are from VPC Endpoint vpce-023cfe82c2d15365c
  # If IPs change, update with: aws ec2 describe-network-interfaces --network-interface-ids <ENI_IDs>
  records = [
    "10.0.1.117", # ap-northeast-1a (eni-08494ca65c0d09b86)
    "10.0.2.221", # ap-northeast-1c (eni-021812412950eafef)
  ]
}

# A record for RDS Proxy Reader endpoint
resource "aws_route53_record" "rds_proxy_reader" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy-reader.endpoint"
  type    = "A"
  ttl     = 60

  # Resource Endpoint IPs for RDS Proxy Reader
  # NOTE: These IPs are from VPC Endpoint vpce-040d0d13a0cbacac6
  # If IPs change, update with: aws ec2 describe-network-interfaces --network-interface-ids <ENI_IDs>
  records = [
    "10.0.1.125", # ap-northeast-1a (eni-0541ff49d5afd8866)
    "10.0.2.86",  # ap-northeast-1c (eni-0ee5cc49c1f3e31d4)
  ]
}

# Outputs for verification
output "rds_proxy_phz_id" {
  description = "Private Hosted Zone ID for RDS Proxy"
  value       = aws_route53_zone.rds_proxy.zone_id
}

output "rds_proxy_writer_dns" {
  description = "DNS name for RDS Proxy Writer (should resolve to Resource Endpoint IPs)"
  value       = aws_route53_record.rds_proxy_writer.fqdn
}

output "rds_proxy_reader_dns" {
  description = "DNS name for RDS Proxy Reader (should resolve to Resource Endpoint IPs)"
  value       = aws_route53_record.rds_proxy_reader.fqdn
}
