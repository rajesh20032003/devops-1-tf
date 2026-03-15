# ============================================================
# ECS Module — Variables
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}
variable "vpc_id" {
  description = "VPC ID — needed for service discovery namespace"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — ECS tasks run here"
  type        = list(string)
}

variable "ecs_tasks_sg_id" {
  description = "ECS tasks security group ID"
  type        = string
}

variable "frontend_tg_arn" {
  description = "Frontend ALB target group ARN"
  type        = string
}

variable "gateway_tg_arn" {
  description = "Gateway ALB target group ARN"
  type        = string
}

variable "user_db_secret_arn" {
  description = "User DB secret ARN from Secrets Manager"
  type        = string
}

variable "order_db_secret_arn" {
  description = "Order DB secret ARN from Secrets Manager"
  type        = string
}

variable "user_db_secret_name" {
  description = "User DB secret name — injected as DB_SECRET_NAME"
  type        = string
}

variable "order_db_secret_name" {
  description = "Order DB secret name — injected as DB_SECRET_NAME"
  type        = string
}

variable "desired_count" {
  description = "Number of tasks to run per service"
  type        = number
  default     = 1
  # dev  = 1 (saves cost!)
  # prod = 2 (high availability!)
}

# ── CPU + Memory per service ──────────────────────────────────
# Fargate pricing: per vCPU/hr + per GB/hr
# 256 CPU units = 0.25 vCPU
# Valid combinations: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
variable "frontend_cpu" {
  description = "Frontend task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Frontend task memory (MB)"
  type        = number
  default     = 512
}

variable "gateway_cpu" {
  description = "Gateway task CPU units"
  type        = number
  default     = 256
}

variable "gateway_memory" {
  description = "Gateway task memory (MB)"
  type        = number
  default     = 512
}

variable "user_service_cpu" {
  description = "User service task CPU units"
  type        = number
  default     = 256
}

variable "user_service_memory" {
  description = "User service task memory (MB)"
  type        = number
  default     = 512
}

variable "order_service_cpu" {
  description = "Order service task CPU units"
  type        = number
  default     = 256
}

variable "order_service_memory" {
  description = "Order service task memory (MB)"
  type        = number
  default     = 512
}