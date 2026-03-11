# ============================================================
# EC2 + ASG + LAUNCH TEMPLATE (2 AZ - Production Grade)
# ============================================================
# Launch Template → defines what each EC2 looks like
# ASG            → ensures 2 EC2s always running (1 per AZ)
#                  auto-replaces failed instances
#                  auto-registers with ALB target groups
# IAM Role       → ECR pull + Secrets Manager (no hardcoded keys!)
# ============================================================

# ── IAM Role ─────────────────────────────────────────────────
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

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
  name = "ecr-pull"
  role = aws_iam_role.ec2.id

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
  name = "secrets-manager-read"
  role = aws_iam_role.ec2.id

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
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Instance Profile ──────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ── Latest Ubuntu 22.04 LTS AMI ──────────────────────────────
data "aws_ami" "ubuntu" {
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
# Defines WHAT each EC2 looks like
# ASG uses this to launch new instances
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-${var.environment}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # base64encode required for Launch Template (unlike direct EC2)
  user_data = base64encode(templatefile(
    "${path.module}/scripts/user_data.sh", {
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
    # create new launch template version BEFORE destroying old
    # ensures zero downtime during template updates
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
# Ensures 2 EC2s ALWAYS running (1 per AZ)
# Auto-replaces failed instances
# Auto-registers new instances with ALB
resource "aws_autoscaling_group" "app" {
  name = "${var.project}-${var.environment}-asg"

  desired_capacity = 2  # always keep 2 running
  min_size         = 2  # never go below 2
  max_size         = 4  # scale up to 4 under high load

  # Span BOTH private subnets (both AZs!)
  # ASG distributes EC2s evenly across AZs automatically
  vpc_zone_identifier = aws_subnet.private[*].id

  # Register EC2s with ALB target groups automatically
  # When new EC2 launches → auto-added to target groups
  # When EC2 terminates  → auto-removed from target groups
  target_group_arns = [
    aws_lb_target_group.frontend.arn,
    aws_lb_target_group.gateway.arn
  ]

  # Use ALB health checks (not just EC2 status)
  # If app is unhealthy → replace EC2 even if instance is running
  health_check_type         = "ELB"
  health_check_grace_period = 120 # wait 2 mins after launch before checking

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest" # always use latest template version
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
    # Ansible uses this tag for dynamic inventory!
    # finds EC2s tagged Role=app-server automatically
  }

  depends_on = [
    aws_nat_gateway.main,
    aws_iam_instance_profile.ec2
  ]
}

# ── Outputs ───────────────────────────────────────────────────
output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}
