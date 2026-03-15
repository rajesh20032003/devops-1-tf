# ============================================================
# VPC Endpoints Module — Main
# ============================================================
# WHY VPC Endpoints?
#
# WITHOUT endpoints (NAT Gateway):
#   ECS task → NAT GW → Internet → ECR/SM/CW → back
#   Traffic leaves AWS network!
#   Costs $0.045/GB data transfer!
#   Security risk (internet exposure)!
#
# WITH endpoints:
#   ECS task → VPC Endpoint → ECR/SM/CW
#   Traffic NEVER leaves AWS network!
#   No data transfer cost!
#   More secure!
#
# TWO types of endpoints:
#
# 1. Gateway Endpoint (FREE!):
#    → Only for S3 and DynamoDB
#    → Just adds a route to route table
#    → No ENI, no IP, no SG needed
#    → Zero cost!
#
# 2. Interface Endpoint ($0.01/hr each):
#    → For all other AWS services
#    → Creates ENI in your subnet
#    → Gets private IP in your VPC
#    → Needs Security Group
#    → DNS resolves service to private IP!
#
# Endpoints we create:
#   s3             → Gateway  (FREE) ECR stores layers here!
#   ecr.api        → Interface       ECR authentication
#   ecr.dkr        → Interface       docker pull image layers
#   logs           → Interface       CloudWatch container logs
#   secretsmanager → Interface       DB credentials at runtime
# ============================================================

# ── S3 Gateway Endpoint (FREE!) ───────────────────────────────
# CRITICAL for ECS Fargate!
# ECR stores Docker image LAYERS in S3!
# Without this → docker pull fails even with ecr endpoints!
#
# Gateway type = just a route table entry
# Points S3 traffic → AWS private network
# No ENI, no SG, completely FREE!
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Add S3 route to ALL private route tables!
  # Each private subnet's route table gets:
  #   destination: pl-xxxxxxxx (S3 prefix list)
  #   target: vpce-xxxxxxxx (this endpoint)
  route_table_ids = var.private_route_table_ids

  tags = {
    Name = "${var.project}-${var.environment}-s3-endpoint"
  }
}

# ── ECR API Interface Endpoint ────────────────────────────────
# ECS agent calls ECR API for:
#   → GetAuthorizationToken (docker login)
#   → DescribeImages
#   → BatchGetImage metadata
#
# Without this:
#   ECS agent can't authenticate to ECR!
#   Task never starts!
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_sg_id]

  # private_dns_enabled = true
  # → DNS resolves api.ecr.ap-south-1.amazonaws.com
  #   to private IP of this endpoint!
  # → ECS agent uses same code, just different IP!
  # → Zero code changes needed! ✅
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-ecr-api-endpoint"
  }
}

# ── ECR DKR Interface Endpoint ────────────────────────────────
# Handles actual Docker image layer downloads!
# When ECS runs docker pull:
#   Step 1: ECR API endpoint → authenticate
#   Step 2: ECR DKR endpoint → download layers
#   Step 3: S3 endpoint      → download actual layer data
#
# All 3 work together for complete docker pull!
# Missing any one → pull fails!
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-ecr-dkr-endpoint"
  }
}

# ── CloudWatch Logs Interface Endpoint ────────────────────────
# ECS Fargate sends container logs to CloudWatch!
# This is how you see logs without SSH!
#
# Container stdout/stderr
#   → FireLens/awslogs log driver
#   → CloudWatch Logs endpoint (private!)
#   → CloudWatch Log Group
#   → You query logs in Console/CLI
#
# Without this endpoint:
#   Logs try to go via NAT GW → internet → CloudWatch
#   More expensive, less secure!
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-logs-endpoint"
  }
}

# ── Secrets Manager Interface Endpoint ────────────────────────
# App fetches DB credentials at runtime!
#
# Flow without endpoint:
#   Container → NAT GW → internet → Secrets Manager ❌
#
# Flow with endpoint:
#   Container → VPC Endpoint → Secrets Manager ✅
#   Credentials NEVER travel over internet!
#   Audit trail in CloudTrail still works!
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-secretsmanager-endpoint"
  }
}