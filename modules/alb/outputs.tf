# ============================================================
# ALB Module — Outputs
# ============================================================
# frontend_tg_arn → ECS frontend service needs this!
# gateway_tg_arn  → ECS gateway service needs this!
# alb_dns_name    → access app via browser!
#
# ECS service uses tg_arn to:
#   → auto-register new tasks when they start
#   → auto-deregister tasks when they stop
#   → ALB always routes to healthy running tasks!
# ============================================================

output "alb_dns_name" {
  description = "ALB DNS — open in browser to see app!"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Full app URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_arn" {
  description = "ALB ARN — needed for listener rules"
  value       = aws_lb.main.arn
}

output "frontend_tg_arn" {
  description = "Frontend target group ARN — passed to ECS frontend service!"
  value       = aws_lb_target_group.frontend.arn
}

output "gateway_tg_arn" {
  description = "Gateway target group ARN — passed to ECS gateway service!"
  value       = aws_lb_target_group.gateway.arn
}