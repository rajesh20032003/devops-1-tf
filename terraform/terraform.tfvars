aws_region           = "ap-south-1"
environment          = "dev"
project              = "micro-dash"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

ec2_instance_type    = "t3.medium"
ec2_key_name         = "ubuntu-01"

ecr_registry         = "760302898980.dkr.ecr.ap-south-1.amazonaws.com"
image_tag            = "latest"
