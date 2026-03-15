# ============================================================
# Dev Environment — Variable Values
# ============================================================

aws_region  = "ap-south-1"
environment = "dev"
project     = "micro-dash"

# ── Networking ────────────────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# ── EC2 (DISABLED — using ECS!) ───────────────────────────────
ec2_enabled       = false
ec2_instance_type = "t3.medium"
ec2_key_name      = "ubuntu-01"

# ── RDS ───────────────────────────────────────────────────────
rds_instance_class = "db.t3.micro"
multi_az           = false   # dev = single AZ saves cost!
postgres_version   = "16.6"

# ── ECS ───────────────────────────────────────────────────────
ecr_registry      = "760302898980.dkr.ecr.ap-south-1.amazonaws.com"
image_tag         = "latest"
ecs_desired_count = 1        # dev = 1 task saves cost!