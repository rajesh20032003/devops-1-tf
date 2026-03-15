# ============================================================
# Security Groups Module — Outputs
# ============================================================
# These IDs are passed to other modules:
#
#   alb_sg_id          → alb module
#   ecs_tasks_sg_id    → ecs module (subnet + task def)
#   rds_sg_id          → rds module
#   vpc_endpoints_sg_id → vpc_endpoints module
#   ec2_sg_id          → ec2 module (archived)
# ============================================================

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "EC2 security group ID (archived)"
  value       = aws_security_group.ec2.id
}

output "ecs_tasks_sg_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

output "rds_sg_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_sg_id" {
  description = "VPC Endpoints security group ID"
  value       = aws_security_group.vpc_endpoints.id
}