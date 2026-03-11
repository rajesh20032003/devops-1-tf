# ============================================================
# SECURITY GROUPS
# ============================================================
# alb_sg → accepts traffic from internet (port 80)
# ec2_sg → accepts traffic ONLY from ALB + Ansible SSH
# rds_sg → accepts traffic ONLY from EC2
# ============================================================

# ── ALB Security Group ────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "ALB - accepts HTTP from internet"
  vpc_id      = aws_vpc.main.id

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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

# ── EC2 Security Group ────────────────────────────────────────
# EC2 is in private subnet
# Only accepts:
#   → app traffic FROM ALB
#   → SSH FROM your IP (for Ansible)
resource "aws_security_group" "ec2" {
  name        = "${var.project}-${var.environment}-ec2-sg"
  description = "EC2 - accepts traffic from ALB only"
  vpc_id      = aws_vpc.main.id

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

  # SSH - for Ansible to connect
  # Industry: use SSM instead of SSH
  # POC: SSH is fine
  ingress {
    description = "SSH for Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # TODO: restrict to your IP in production
    # cidr_blocks = ["YOUR_IP/32"]
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

# ── RDS Security Group ────────────────────────────────────────
# RDS only accepts connections from EC2
# Never from internet!
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "RDS - accepts connections from EC2 only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2 only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
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

# ── Outputs ───────────────────────────────────────────────────
output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ec2_sg_id" {
  value = aws_security_group.ec2.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}
