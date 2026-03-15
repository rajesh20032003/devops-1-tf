# ============================================================
# Dev Environment — Outputs
# ============================================================

# ── App Access ────────────────────────────────────────────────
output "app_url" {
  description = "Open this in browser!"
  value       = module.alb.app_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

# ── ECS ───────────────────────────────────────────────────────
output "ecs_cluster_name" {
  description = "ECS cluster name — used by Jenkins CD!"
  value       = module.ecs.cluster_name
}

output "frontend_service_name" {
  description = "Frontend ECS service name"
  value       = module.ecs.frontend_service_name
}

output "gateway_service_name" {
  description = "Gateway ECS service name"
  value       = module.ecs.gateway_service_name
}

output "user_service_name" {
  description = "User service ECS service name"
  value       = module.ecs.user_service_name
}

output "order_service_name" {
  description = "Order service ECS service name"
  value       = module.ecs.order_service_name
}

# ── RDS ───────────────────────────────────────────────────────
output "user_db_secret_name" {
  description = "User DB secret name"
  value       = module.rds.user_db_secret_name
}

output "order_db_secret_name" {
  description = "Order DB secret name"
  value       = module.rds.order_db_secret_name
}

# ── Networking ────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}