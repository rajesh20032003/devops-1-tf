# ============================================================
# EC2 Module — Outputs
# ============================================================
# All outputs use try() because resources may not exist
# when enabled=false → avoids null reference errors!
#
# try(value, fallback):
#   if value exists → return value
#   if value is null → return fallback ("")
# ============================================================

output "asg_name" {
  description = "ASG name — used by Jenkins SSM deploy"
  value       = var.enabled ? aws_autoscaling_group.app[0].name : ""
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = var.enabled ? aws_launch_template.app[0].id : ""
}

output "ec2_role_arn" {
  description = "EC2 IAM role ARN"
  value       = var.enabled ? aws_iam_role.ec2[0].arn : ""
}