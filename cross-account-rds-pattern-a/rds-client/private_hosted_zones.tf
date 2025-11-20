# Private Hosted Zones for DNS-based Resource Endpoints (CNAME version)
#
# DNS-based Resource Configurations do not create Private Hosted Zones automatically.
# We need to manually create PHZs and CNAME records pointing to the Resource Endpoint DNS names.
#
# This version uses CNAME records instead of A records with IPs.

# Private Hosted Zone for RDS Proxy (proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com)
resource "aws_route53_zone" "rds_proxy" {
  name = "proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name        = "pattern-a-rds-proxy-phz"
    Description = "Private Hosted Zone for RDS Proxy DNS-based Resource Endpoints"
  }
}

# CNAME record for RDS Proxy Writer endpoint
# Points to the Resource Endpoint VPC Endpoint DNS name
resource "aws_route53_record" "rds_proxy_writer" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy"
  type    = "CNAME"
  ttl     = 60

  # Use the first DNS entry from the Resource Endpoint VPC Endpoint
  records = [aws_vpc_endpoint.rds_proxy_writer.dns_entry[0].dns_name]
}

# CNAME record for RDS Proxy Reader endpoint
# Points to the Resource Endpoint VPC Endpoint DNS name
resource "aws_route53_record" "rds_proxy_reader" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy-reader.endpoint"
  type    = "CNAME"
  ttl     = 60

  # Use the first DNS entry from the Resource Endpoint VPC Endpoint
  records = [aws_vpc_endpoint.rds_proxy_reader.dns_entry[0].dns_name]
}

# Outputs for verification
output "rds_proxy_phz_id" {
  description = "Private Hosted Zone ID for RDS Proxy"
  value       = aws_route53_zone.rds_proxy.zone_id
}

output "rds_proxy_writer_dns" {
  description = "DNS name for RDS Proxy Writer (should resolve to Resource Endpoint via CNAME)"
  value       = aws_route53_record.rds_proxy_writer.fqdn
}

output "rds_proxy_reader_dns" {
  description = "DNS name for RDS Proxy Reader (should resolve to Resource Endpoint via CNAME)"
  value       = aws_route53_record.rds_proxy_reader.fqdn
}

output "rds_proxy_writer_cname_target" {
  description = "CNAME target for RDS Proxy Writer (Resource Endpoint VPC Endpoint DNS)"
  value       = aws_vpc_endpoint.rds_proxy_writer.dns_entry[0].dns_name
}

output "rds_proxy_reader_cname_target" {
  description = "CNAME target for RDS Proxy Reader (Resource Endpoint VPC Endpoint DNS)"
  value       = aws_vpc_endpoint.rds_proxy_reader.dns_entry[0].dns_name
}
