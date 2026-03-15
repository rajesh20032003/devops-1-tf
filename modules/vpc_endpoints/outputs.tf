
# ============================================================
# VPC Endpoints Module — Outputs
# ============================================================

output "s3_endpoint_id" {
  description = "S3 Gateway endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "ecr_api_endpoint_id" {
  description = "ECR API Interface endpoint ID"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_endpoint_id" {
  description = "ECR DKR Interface endpoint ID"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "cloudwatch_logs_endpoint_id" {
  description = "CloudWatch Logs Interface endpoint ID"
  value       = aws_vpc_endpoint.cloudwatch_logs.id
}

output "secretsmanager_endpoint_id" {
  description = "Secrets Manager Interface endpoint ID"
  value       = aws_vpc_endpoint.secretsmanager.id
}