resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  # enable_dns_support required for VPC Endpoints!
  # Without this → endpoints don't resolve! ✅
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# ── Internet Gateway ─────────────────────────────────────────
# Door between VPC and internet
# ALB needs this to receive public traffic
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# ── Public Subnets ───────────────────────────────────────────
# ALB and NAT Gateways live here
# map_public_ip_on_launch = true (resources get public IPs)
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
  }
}

# ── Private Subnets ──────────────────────────────────────────
# ECS Fargate tasks and RDS live here
# map_public_ip_on_launch = false (no direct internet!)
# K8s tags kept for future EKS migration!
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
    # K8s tags for future EKS use!
    "kubernetes.io/role/internal-elb"                         = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }
}

# ── Elastic IPs for NAT Gateways ─────────────────────────────
# Each NAT GW needs a static public IP
# ECS tasks use this IP for outbound traffic
resource "aws_eip" "nat" {
  count      = 2
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip-${count.index + 1}"
  }
}

# ── NAT Gateways ─────────────────────────────────────────────
# One per AZ for high availability!
# AZ1 NAT GW → AZ1 private subnet outbound
# AZ2 NAT GW → AZ2 private subnet outbound
# If AZ1 goes down → AZ2 unaffected! ✅
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project}-${var.environment}-nat-gw-${count.index + 1}"
  }
}

# ── Public Route Table ───────────────────────────────────────
# All public subnets share ONE route table
# 0.0.0.0/0 → IGW (internet access!)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Tables ─────────────────────────────────────
# Each AZ gets its OWN route table → own NAT GW
# AZ isolation! If NAT GW1 fails → AZ2 still works!
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project}-${var.environment}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}