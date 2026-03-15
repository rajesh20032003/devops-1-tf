# ============================================================
# Dev Environment — Backend
# ============================================================
# Separate state file for dev!
# key = "dev/terraform.tfstate"
#
# Why separate state per environment?
#   → dev destroy won't touch prod state!
#   → prod destroy won't touch dev state!
#   → completely isolated! ✅
# ============================================================
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    encrypt = true
    # bucket, key, region, dynamodb_table
    # injected by GitHub Actions!
    # -backend-config="bucket=..."
    # -backend-config="key=dev/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project     = "micro-dash"
      environment = "dev"
      managedby   = "terraform"
      owner       = "rajesh"
    }
  }
}