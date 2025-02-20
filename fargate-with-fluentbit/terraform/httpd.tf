resource "aws_cloudwatch_log_group" "httpd" {
  name              = "/aws/ecs/httpd"
  retention_in_days = 1
}

resource "aws_iam_role" "httpd" {
  name               = "httpd"
  assume_role_policy = data.aws_iam_policy_document.httpd_assume_role.json
}

data "aws_iam_policy_document" "httpd_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "httpd" {
  role       = aws_iam_role.httpd.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "httpd" {
  name            = "httpd"
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  security_groups = [aws_security_group.httpd.id]
}

resource "aws_lb_listener" "httpd" {
  load_balancer_arn = aws_lb.httpd.arn
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.httpd.arn
  }
}

resource "aws_lb_target_group" "httpd" {
  vpc_id      = aws_vpc.example.id
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
}

resource "aws_security_group" "httpd" {
  vpc_id = aws_vpc.example.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "dns_name" {
  value = aws_lb.httpd.dns_name
}
