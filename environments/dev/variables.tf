# ============================================================
# Dev Environment — Variables
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "micro-dash"
}

# ── Networking ────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# ── EC2 (archived) ────────────────────────────────────────────
variable "ec2_enabled" {
  description = "Enable EC2 deployment (false = using ECS!)"
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "ubuntu-01"
}

# ── RDS ───────────────────────────────────────────────────────
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "RDS Multi-AZ (false in dev saves cost!)"
  type        = bool
  default     = false
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16.6"
}

# ── ECS ───────────────────────────────────────────────────────
variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "ecs_desired_count" {
  description = "ECS desired task count per service"
  type        = number
  default     = 1
  # dev  = 1 (saves cost!)
  # prod = 2 (high availability!)
}