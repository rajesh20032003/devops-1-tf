# ============================================================
# Dev Environment — Main
# ============================================================
# This file CONNECTS all modules together!
# Passes outputs from one module as inputs to another!
#
# Data flow:
#   vpc → security_groups → alb
#                         → rds
#                         → vpc_endpoints
#                         → ecs
#                         → ec2 (disabled!)
# ============================================================

# ── Module: VPC ───────────────────────────────────────────────
# Creates all networking:
# VPC, subnets, IGW, NAT GWs, route tables
module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ── Module: Security Groups ───────────────────────────────────
# Creates all SGs:
# alb_sg, ec2_sg, ecs_tasks_sg, rds_sg, vpc_endpoints_sg
#
# Notice: vpc_id comes from vpc module output!
# module.vpc.vpc_id → this is how modules connect!
module "security_groups" {
  source = "../../modules/security_groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id      # ← from vpc module!
  vpc_cidr    = module.vpc.vpc_cidr    # ← from vpc module!
}

# ── Module: ALB ───────────────────────────────────────────────
# Creates ALB + target groups + listeners
# target_type = ip (for ECS Fargate tasks!)
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids  # ALB in public!
  alb_sg_id         = module.security_groups.alb_sg_id
}

# ── Module: RDS ───────────────────────────────────────────────
# Creates RDS user-db + order-db + Secrets Manager
# multi_az = false in dev (saves ~$0.07/hr!)
module "rds" {
  source = "../../modules/rds"

  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.vpc.private_subnet_ids # RDS in private!
  rds_sg_id          = module.security_groups.rds_sg_id
  instance_class     = var.rds_instance_class
  multi_az           = var.multi_az
  postgres_version   = var.postgres_version
}

# ── Module: VPC Endpoints ─────────────────────────────────────
# Creates private endpoints for ECR, CW, SM
# ECS tasks use these instead of NAT GW!
# Traffic stays inside AWS network!
module "vpc_endpoints" {
  source = "../../modules/vpc_endpoints"

  project                 = var.project
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  aws_region              = var.aws_region
  private_subnet_ids      = module.vpc.private_subnet_ids
  vpc_endpoints_sg_id     = module.security_groups.vpc_endpoints_sg_id
  private_route_table_ids = module.vpc.private_route_table_ids
}

# ── Module: ECS ───────────────────────────────────────────────
# Creates ECS cluster, task definitions, services
# Connects to ALB target groups for traffic routing
# Uses Secrets Manager for DB credentials
# Service Discovery for internal communication!
module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  vpc_id      = module.vpc.vpc_id

  # Images
  ecr_registry = var.ecr_registry
  image_tag    = var.image_tag

  # Networking — tasks in private subnets!
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_tasks_sg_id    = module.security_groups.ecs_tasks_sg_id

  # ALB target groups — ECS registers tasks here!
  frontend_tg_arn = module.alb.frontend_tg_arn
  gateway_tg_arn  = module.alb.gateway_tg_arn

  # DB secrets — task definition injects DB_SECRET_NAME
  user_db_secret_arn   = module.rds.user_db_secret_arn
  order_db_secret_arn  = module.rds.order_db_secret_arn
  user_db_secret_name  = module.rds.user_db_secret_name
  order_db_secret_name = module.rds.order_db_secret_name

  # Scale
  desired_count = var.ecs_desired_count

  # Wait for VPC endpoints before ECS tasks start!
  # Otherwise docker pull fails (no ECR endpoint yet!)
  depends_on = [module.vpc_endpoints]
}

# ── Module: EC2 (DISABLED!) ───────────────────────────────────
# enabled = false → NO resources created!
# Kept for reference and easy rollback!
# Switch enabled = true to revert to EC2 deployment
module "ec2" {
  source = "../../modules/ec2"

  enabled     = var.ec2_enabled  # false!
  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  instance_type      = var.ec2_instance_type
  key_name           = var.ec2_key_name
  ec2_sg_id          = module.security_groups.ec2_sg_id
  private_subnet_ids = module.vpc.private_subnet_ids
  frontend_tg_arn    = module.alb.frontend_tg_arn
  gateway_tg_arn     = module.alb.gateway_tg_arn
}