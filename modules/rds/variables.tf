# ============================================================
# RDS Module — Variables
# ============================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — RDS lives here"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS security group ID — from security_groups module"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = false
  # dev  = false (saves cost!)
  # prod = true  (HA required!)
}

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.6"
}