variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — from vpc module"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — ALB lives here"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB security group ID — from security_groups module"
  type        = string
}