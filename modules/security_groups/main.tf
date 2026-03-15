# ============================================================
# Security Groups Module — Main
# ============================================================
# Creates 4 Security Groups:
#
#   alb_sg          → accepts HTTP/HTTPS from internet
#   ec2_sg          → accepts traffic from ALB only (ARCHIVED)
#   ecs_tasks_sg    → accepts traffic from ALB only (NEW!)
#   rds_sg          → accepts 5432 from ECS tasks only
#   vpc_endpoints_sg → accepts 443 from ECS tasks only
#
# Security model (least privilege):
#   Internet → ALB → ECS tasks → RDS
#   ECS tasks → VPC Endpoints (ECR, SM, CW)
#   NO direct internet access to ECS or RDS!
# ============================================================

# ── ALB Security Group ────────────────────────────────────────
# Accepts HTTP/HTTPS from anywhere on internet
# Forwards to ECS tasks internally
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "ALB - accepts HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

# ── EC2 Security Group (ARCHIVED - kept for reference) ────────
# Used when deployment_type = "ec2"
# Ports 100 (frontend) and 3000 (gateway) from ALB
# Port 22 for SSH (was needed for Ansible)
# Now replaced by ECS tasks SG!
resource "aws_security_group" "ec2" {
  name        = "${var.project}-${var.environment}-ec2-sg"
  description = "EC2 - ARCHIVED - use ecs_tasks_sg instead"
  vpc_id      = var.vpc_id

  # Frontend port - only from ALB
  ingress {
    description     = "Frontend from ALB"
    from_port       = 100
    to_port         = 100
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Gateway port - only from ALB
  ingress {
    description     = "Gateway from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH was needed for Ansible
  # Replaced by SSM in EC2 deployment
  # Not needed at all in ECS!
  ingress {
    description = "SSH - ARCHIVED (use SSM instead)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-ec2-sg"
  }
}

# ── ECS Tasks Security Group (NEW!) ──────────────────────────
# Replaces EC2 SG for Fargate tasks
# Key differences from EC2 SG:
#   → No port 22 (no SSH ever!)
#   → No port 100 (frontend runs on 80 in ECS!)
#   → Allows outbound to RDS SG (explicit!)
#   → Allows outbound to VPC endpoints SG (explicit!)
#   → Each Fargate task gets its OWN ENI + private IP
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project}-${var.environment}-ecs-tasks-sg"
  description = "ECS Fargate tasks - accepts traffic from ALB only"
  vpc_id      = var.vpc_id

  # Frontend container - port 80
  # (was port 100 in EC2, ECS uses standard 80!)
  ingress {
    description     = "Frontend from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Gateway container - port 3000
  ingress {
    description     = "Gateway from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # User service - port 3001
  # Gateway calls user-service internally via service discovery
  ingress {
    description = "User service internal"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Order service - port 3002
  # Gateway calls order-service internally via service discovery
  ingress {
    description = "Order service internal"
    from_port   = 3002
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound: ALL allowed
  # ECS tasks need to reach:
  #   → RDS (port 5432)
  #   → VPC Endpoints (port 443)
  #   → ECR via VPC Endpoint
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-ecs-tasks-sg"
  }
}

# ── RDS Security Group ────────────────────────────────────────
# UPDATED: now accepts from ECS tasks SG instead of EC2 SG!
# Port 5432 PostgreSQL only from ECS tasks
# Zero internet access to RDS ever!
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "RDS - accepts PostgreSQL from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Points to ECS tasks SG (not EC2 SG anymore!)
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-rds-sg"
  }
}

# ── VPC Endpoints Security Group (NEW!) ───────────────────────
# VPC Endpoints are Interface type = they get ENIs in subnet
# ENIs need SG to control who can talk to them
#
# Who needs to reach endpoints?
#   → ECS tasks (pull from ECR, fetch secrets, write logs)
#
# Port 443 because all AWS APIs use HTTPS!
#
# Without this SG:
#   → ECS tasks can't reach ECR endpoint
#   → docker pull fails!
#   → Container never starts!
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-${var.environment}-vpc-endpoints-sg"
  description = "VPC Endpoints - accepts HTTPS from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from ECS tasks to AWS services"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    # Only ECS tasks can use these endpoints!
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-vpc-endpoints-sg"
  }
}