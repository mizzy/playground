# Data source to get VPC Endpoint created by RDS Proxy default endpoint
# Note: Using explicit ID to distinguish from reader endpoint VPC Endpoint
data "aws_vpc_endpoint" "rds_proxy" {
  id = "vpce-03357c6219eec9777"
}

# Data source to get RDS Proxy VPC Endpoint ENI IDs
data "aws_network_interfaces" "rds_proxy" {
  filter {
    name   = "description"
    values = ["VPC Endpoint Interface ${data.aws_vpc_endpoint.rds_proxy.id}"]
  }

  filter {
    name   = "vpc-id"
    values = [aws_vpc.main.id]
  }

  depends_on = [data.aws_vpc_endpoint.rds_proxy]
}

# Data source to get individual ENI details
data "aws_network_interface" "rds_proxy" {
  count = length(data.aws_network_interfaces.rds_proxy.ids)
  id    = tolist(data.aws_network_interfaces.rds_proxy.ids)[count.index]
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "rds-proxy-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "rds-proxy-nlb"
  }
}

# Target Group for RDS Proxy
resource "aws_lb_target_group" "rds_proxy" {
  name        = "rds-proxy-tg"
  port        = 5432
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = 5432
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "rds-proxy-tg"
  }
}

# Register RDS Proxy ENI IPs as targets
resource "aws_lb_target_group_attachment" "rds_proxy" {
  count            = length(data.aws_network_interface.rds_proxy)
  target_group_arn = aws_lb_target_group.rds_proxy.arn
  target_id        = data.aws_network_interface.rds_proxy[count.index].private_ip
  port             = 5432
}

# NLB Listener
resource "aws_lb_listener" "rds_proxy" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 5432
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rds_proxy.arn
  }
}

# VPC Endpoint Service
resource "aws_vpc_endpoint_service" "rds_proxy" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb.arn]

  tags = {
    Name = "rds-proxy-endpoint-service"
  }
}

# Allow rds-client account to connect
resource "aws_vpc_endpoint_service_allowed_principal" "rds_client" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.rds_proxy.id
  principal_arn           = "arn:aws:iam::914357407416:root"
}

# Outputs
output "nlb_dns_name" {
  value       = aws_lb.nlb.dns_name
  description = "NLB DNS name"
}

output "vpc_endpoint_service_name" {
  value       = aws_vpc_endpoint_service.rds_proxy.service_name
  description = "VPC Endpoint Service name for PrivateLink"
}

output "vpc_endpoint_service_id" {
  value       = aws_vpc_endpoint_service.rds_proxy.id
  description = "VPC Endpoint Service ID"
}
