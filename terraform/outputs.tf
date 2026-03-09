output "vpc_id" {
  description = "VPC ID — used by EC2, ECS, EKS modules"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs — used for ALB and EC2"
  value       = aws_subnet.public[*].id
  # [*] = all elements of the list
  # returns: ["subnet-abc123", "subnet-def456"]
}

output "vpc_cidr" {
  description = "VPC CIDR — used in security group rules"
  value       = aws_vpc.main.cidr_block
}