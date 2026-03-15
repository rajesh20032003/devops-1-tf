# ============================================================
# EC2 Module — Variables
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "enabled" {
  description = "Enable EC2 deployment (false = using ECS!)"
  type        = bool
  default     = false
  # dev  = false (using ECS Fargate!)
  # Switch to true to revert to EC2 deployment
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "ec2_sg_id" {
  description = "EC2 security group ID — from security_groups module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — EC2 lives here"
  type        = list(string)
}

variable "frontend_tg_arn" {
  description = "Frontend target group ARN — from alb module"
  type        = string
}

variable "gateway_tg_arn" {
  description = "Gateway target group ARN — from alb module"
  type        = string
}