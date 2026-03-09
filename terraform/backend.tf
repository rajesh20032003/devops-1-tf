terraform {
  required_version = ">= 1.7.0"
  required_providers {
    source = "hashicorp/aws"
    version = "~> 5.0"
  }
  backend "s3" {
  encrypt = true
}
  
}

provider "aws" {
  region = var.aws_region
  default_tags  {
    tags = {
      project = "micro-dash"
      managedby = "terraform"
      owner = "rajesh"
    }
  }
}

