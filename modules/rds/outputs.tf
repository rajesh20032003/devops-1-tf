# ============================================================
# RDS Module — Outputs
# ============================================================
# user_db_secret_arn  → ECS task definition needs this!
# order_db_secret_arn → ECS task definition needs this!
#
# How ECS uses secrets:
#   Task Definition references secret ARN
#   ECS Task Execution Role fetches secret
#   Injects as environment variable into container
#   App reads DB_SECRET_NAME env var at startup
#   Calls Secrets Manager API to get full credentials
# ============================================================

output "user_db_secret_arn" {
  description = "User DB secret ARN — passed to ECS task definition"
  value       = aws_secretsmanager_secret.user_db.arn
}

output "order_db_secret_arn" {
  description = "Order DB secret ARN — passed to ECS task definition"
  value       = aws_secretsmanager_secret.order_db.arn
}

output "user_db_secret_name" {
  description = "User DB secret name — passed as DB_SECRET_NAME env var"
  value       = aws_secretsmanager_secret.user_db.name
}

output "order_db_secret_name" {
  description = "Order DB secret name — passed as DB_SECRET_NAME env var"
  value       = aws_secretsmanager_secret.order_db.name
}

output "user_db_endpoint" {
  description = "User DB endpoint — for debugging only"
  value       = aws_db_instance.user_db.address
  sensitive   = true
}

output "order_db_endpoint" {
  description = "Order DB endpoint — for debugging only"
  value       = aws_db_instance.order_db.address
  sensitive   = true
}