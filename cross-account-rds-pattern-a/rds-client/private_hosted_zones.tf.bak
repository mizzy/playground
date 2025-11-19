# Private Hosted Zones for DNS-based Resource Endpoints
#
# DNS-based Resource Configurations do not create Private Hosted Zones automatically.
# We need to manually create PHZs and A records pointing to the Resource Endpoint IPs.
#
# IPs are dynamically retrieved from VPC Endpoint Network Interfaces.

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

# Get Network Interfaces for RDS Proxy Writer Resource Endpoint
data "aws_network_interface" "rds_proxy_writer" {
  for_each = toset(aws_vpc_endpoint.rds_proxy_writer.network_interface_ids)
  id       = each.value
}

# Get Network Interfaces for RDS Proxy Reader Resource Endpoint
data "aws_network_interface" "rds_proxy_reader" {
  for_each = toset(aws_vpc_endpoint.rds_proxy_reader.network_interface_ids)
  id       = each.value
}

# A record for RDS Proxy Writer endpoint
resource "aws_route53_record" "rds_proxy_writer" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy"
  type    = "A"
  ttl     = 60

  # Dynamically get IPs from Resource Endpoint Network Interfaces
  records = [for ni in data.aws_network_interface.rds_proxy_writer : ni.private_ip]
}

# A record for RDS Proxy Reader endpoint
resource "aws_route53_record" "rds_proxy_reader" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-a-rds-proxy-reader.endpoint"
  type    = "A"
  ttl     = 60

  # Dynamically get IPs from Resource Endpoint Network Interfaces
  records = [for ni in data.aws_network_interface.rds_proxy_reader : ni.private_ip]
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
