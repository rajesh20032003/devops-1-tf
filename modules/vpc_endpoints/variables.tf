# ============================================================
# VPC Endpoints Module — Variables
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
  description = "VPC ID — from vpc module"
  type        = string
}

variable "aws_region" {
  description = "AWS region — needed to build endpoint service names"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — Interface endpoints live here"
  type        = list(string)
}

variable "vpc_endpoints_sg_id" {
  description = "VPC Endpoints security group ID — from security_groups module"
  type        = string
}

variable "private_route_table_ids" {
  description = "Private route table IDs — S3 Gateway endpoint needs this"
  type        = list(string)
}