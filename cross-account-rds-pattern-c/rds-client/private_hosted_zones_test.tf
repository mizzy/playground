# Private Hosted Zones for testing standard DNS names with VPC Lattice
#
# Maps original RDS Proxy DNS names to VPC Lattice DNS names via CNAME

# Private Hosted Zone for RDS Proxy (proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com)
resource "aws_route53_zone" "rds_proxy" {
  name = "proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name        = "pattern-c-rds-proxy-phz"
    Description = "Private Hosted Zone for RDS Proxy with VPC Lattice DNS CNAME mapping"
  }
}

# CNAME record for RDS Proxy Writer endpoint
# Maps original DNS name to VPC Lattice DNS name
resource "aws_route53_record" "rds_proxy_writer" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-c-rds-proxy"
  type    = "CNAME"
  ttl     = 60

  # VPC Lattice DNS name for RDS Proxy Writer
  records = ["snra-05c8959f3dedd93ed.rcfg-0c830603dadd13ccf.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"]
}

# CNAME record for RDS Proxy Reader endpoint
# Maps original DNS name to VPC Lattice DNS name
resource "aws_route53_record" "rds_proxy_reader" {
  zone_id = aws_route53_zone.rds_proxy.zone_id
  name    = "pattern-c-rds-proxy-reader.endpoint"
  type    = "CNAME"
  ttl     = 60

  # VPC Lattice DNS name for RDS Proxy Reader
  records = ["snra-0729f435aaa8c3406.rcfg-04ed74564b8ec0549.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"]
}

# Outputs for verification
output "rds_proxy_phz_id" {
  description = "Private Hosted Zone ID for RDS Proxy"
  value       = aws_route53_zone.rds_proxy.zone_id
}

output "rds_proxy_writer_dns" {
  description = "DNS name for RDS Proxy Writer (should resolve via CNAME to VPC Lattice)"
  value       = aws_route53_record.rds_proxy_writer.fqdn
}

output "rds_proxy_reader_dns" {
  description = "DNS name for RDS Proxy Reader (should resolve via CNAME to VPC Lattice)"
  value       = aws_route53_record.rds_proxy_reader.fqdn
}

output "rds_proxy_writer_cname_target" {
  description = "CNAME target for RDS Proxy Writer (VPC Lattice DNS)"
  value       = tolist(aws_route53_record.rds_proxy_writer.records)[0]
}

output "rds_proxy_reader_cname_target" {
  description = "CNAME target for RDS Proxy Reader (VPC Lattice DNS)"
  value       = tolist(aws_route53_record.rds_proxy_reader.records)[0]
}
