# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================
# ALB spans BOTH public subnets (2 AZs) ✅
# Path based routing:
#   /api/* → gateway  (port 3000)
#   /*     → frontend (port 100)
#
# NOTE: No manual target group attachments here!
# ASG automatically registers/deregisters EC2s ✅
# ============================================================

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# ── Target Group: Frontend ────────────────────────────────────
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project}-${var.environment}-fe-tg"
  port     = 100
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "100"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project}-${var.environment}-fe-tg"
  }
}

# ── Target Group: Gateway ─────────────────────────────────────
resource "aws_lb_target_group" "gateway" {
  name     = "${var.project}-${var.environment}-gw-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "3000"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project}-${var.environment}-gw-tg"
  }
}

# ── NO manual target group attachments! ──────────────────────
# ASG automatically registers EC2s when they launch
# ASG automatically deregisters EC2s when they terminate
# This is the correct production approach ✅

# ── Listener: HTTP port 80 ────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default → frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ── Listener Rule: /api/* → Gateway ──────────────────────────
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# ── Outputs ───────────────────────────────────────────────────
output "alb_dns_name" {
  description = "Open this in browser to see your app!"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}
