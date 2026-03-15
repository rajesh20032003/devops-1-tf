# ============================================================
# EC2 Module — Main (ARCHIVED — deployment_type = "ec2")
# ============================================================
# ALL resources use count = var.enabled ? 1 : 0
#
# enabled = false (default) → NO resources created!
# enabled = true            → Full EC2 + ASG created!
#
# Why keep this module?
#   ✅ Shows migration journey EC2 → ECS
#   ✅ Can switch back with enabled=true
#   ✅ Portfolio + interview value!
#   ✅ Real companies keep rollback options!
#
# What was replaced by ECS:
#   Launch Template → Task Definition
#   ASG             → ECS Service (desired count)
#   EC2 IAM Role    → ECS Task Execution Role
#   SSM deploy.sh   → aws ecs update-service
#   docker run      → ECS manages containers!
# ============================================================

# ── IAM Role ─────────────────────────────────────────────────
# count trick:
#   enabled=true  → count=1 → resource created
#   enabled=false → count=0 → resource SKIPPED!
resource "aws_iam_role" "ec2" {
  count = var.enabled ? 1 : 0
  name  = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ec2-role"
  }
}

# ── ECR Pull Policy ───────────────────────────────────────────
resource "aws_iam_role_policy" "ecr_pull" {
  count = var.enabled ? 1 : 0
  name  = "ecr-pull"
  role  = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

# ── Secrets Manager Read Policy ───────────────────────────────
resource "aws_iam_role_policy" "secrets_read" {
  count = var.enabled ? 1 : 0
  name  = "secrets-manager-read"
  role  = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "*"
    }]
  })
}

# ── SSM Policy ────────────────────────────────────────────────
# SSM Managed Instance Core:
#   → SSM Session Manager (no SSH needed!)
#   → SSM Run Command (Jenkins deploy via SSM!)
#   → SSM Parameter Store access
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Instance Profile ──────────────────────────────────────────
# EC2 uses instance profile to assume IAM role
# ECS uses task execution role instead (no instance profile!)
resource "aws_iam_instance_profile" "ec2" {
  count = var.enabled ? 1 : 0
  name  = "${var.project}-${var.environment}-ec2-profile"
  role  = aws_iam_role.ec2[0].name
}

# ── Latest Ubuntu 22.04 LTS AMI ──────────────────────────────
# only fetched when enabled=true
# saves API calls when EC2 is disabled!
data "aws_ami" "ubuntu" {
  count       = var.enabled ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical official

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Launch Template ───────────────────────────────────────────
# Replaced by ECS Task Definition!
#
# Launch Template → what EC2 looks like (AMI, type, SG)
# Task Definition → what container looks like (image, cpu, memory)
resource "aws_launch_template" "app" {
  count         = var.enabled ? 1 : 0
  name_prefix   = "${var.project}-${var.environment}-"
  image_id      = data.aws_ami.ubuntu[0].id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2[0].name
  }

  vpc_security_group_ids = [var.ec2_sg_id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile(
    "${path.module}/user_data.sh", {
      aws_region = var.aws_region
    }
  ))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project}-${var.environment}-app-server"
      Role = "app-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
# Replaced by ECS Service!
#
# ASG desired_count=2 → always 2 EC2s running
# ECS desired_count=2 → always 2 tasks running
# Same concept, different technology!
resource "aws_autoscaling_group" "app" {
  count = var.enabled ? 1 : 0
  name  = "${var.project}-${var.environment}-asg"

  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [
    var.frontend_tg_arn,
    var.gateway_tg_arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "aws:autoscaling:groupName"
    value               = "${var.project}-${var.environment}-asg"
    propagate_at_launch = true
  }
}