# ============================================================
# Security Groups Module — Variables
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — from vpc module output"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR — used for VPC endpoint SG rule"
  type        = string
}