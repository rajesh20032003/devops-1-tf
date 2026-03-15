# ============================================================
# ALB Module — Main
# ============================================================
# Creates:
#   → Application Load Balancer (internet-facing)
#   → Target Group: frontend (type=ip, port=80)
#   → Target Group: gateway  (type=ip, port=3000)
#   → Listener: HTTP port 80
#   → Listener Rule: /api/* → gateway
#
# KEY CHANGE from EC2:
#   EC2: target_type = "instance"
#        ALB registers EC2 instance IDs
#        ASG auto-registers on launch
#
#   ECS: target_type = "ip"
#        ALB registers Fargate task private IPs
#        ECS service auto-registers tasks on start!
#        No manual registration needed! ✅
#
# Why target_type=ip for ECS?
#   Fargate tasks get their OWN ENI + private IP
#   There is NO EC2 instance ID to register!
#   ALB talks directly to task's private IP!
# ============================================================

# ── Application Load Balancer ─────────────────────────────────
# internet-facing = has public IP
# spans both public subnets = 2 AZ high availability!
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# ── Target Group: Frontend ────────────────────────────────────
# type = "ip" → ECS Fargate task private IPs registered here!
# port 80 → frontend container listens on 80 in ECS
#           (was port 100 in EC2 docker run -p 100:80)
#           (ECS maps container port 80 directly!)
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project}-${var.environment}-fe-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Health check on root path
  # ALB pings / every 30s
  # 2 consecutive success = healthy
  # 3 consecutive failure = unhealthy → stop routing!
  health_check {
    enabled             = true
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Important for ECS rolling deployments!
  # When old task is draining:
  # ALB waits this many seconds before deregistering
  # Allows in-flight requests to complete
  deregistration_delay = 30

  tags = {
    Name = "${var.project}-${var.environment}-fe-tg"
  }
}

# ── Target Group: Gateway ─────────────────────────────────────
# type = "ip" → ECS Fargate task private IPs registered here!
# port 3000 → gateway container listens on 3000
# /health endpoint → gateway has this route!
resource "aws_lb_target_group" "gateway" {
  name        = "${var.project}-${var.environment}-gw-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

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

  deregistration_delay = 30

  tags = {
    Name = "${var.project}-${var.environment}-gw-tg"
  }
}

# ── Listener: HTTP port 80 ────────────────────────────────────
# Default action → frontend
# Any request that doesn't match rules → frontend
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ── Listener Rule: /api/* → Gateway ──────────────────────────
# Priority 100 = checked BEFORE default rule
# /api/* matches → forward to gateway target group
# gateway aggregates user-service + order-service data
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