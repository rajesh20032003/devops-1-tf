# ============================================================
# VPC Module — Outputs
# ============================================================
# These values are used by OTHER modules!
# security_groups → needs vpc_id
# alb             → needs public_subnet_ids
# ecs             → needs private_subnet_ids
# rds             → needs private_subnet_ids
# vpc_endpoints   → needs vpc_id, private_subnet_ids
# ============================================================

output "vpc_id" {
  description = "VPC ID — used by all other modules"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs — ALB lives here"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — ECS tasks + RDS live here"
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs — vpc_endpoints S3 gateway needs this"
  value       = aws_route_table.private[*].id
}

output "vpc_cidr" {
  description = "VPC CIDR block — used in security group rules"
  value       = aws_vpc.main.cidr_block
}