# ============================================================
# ECS Module — Outputs
# ============================================================
# Jenkins CD pipeline needs:
#   cluster_name → aws ecs update-service --cluster
#   service names → aws ecs update-service --service

output "cluster_name" {
  description = "ECS cluster name — Jenkins CD uses this"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "frontend_service_name" {
  description = "Frontend ECS service name"
  value       = aws_ecs_service.frontend.name
}

output "gateway_service_name" {
  description = "Gateway ECS service name"
  value       = aws_ecs_service.gateway.name
}

output "user_service_name" {
  description = "User service ECS service name"
  value       = aws_ecs_service.user_service.name
}

output "order_service_name" {
  description = "Order service ECS service name"
  value       = aws_ecs_service.order_service.name
}

output "task_execution_role_arn" {
  description = "Task execution role ARN"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "Task role ARN"
  value       = aws_iam_role.task.arn
}