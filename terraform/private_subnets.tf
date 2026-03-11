# ============================================================
# PRIVATE SUBNETS + NAT GATEWAYS (2 AZ - Production Grade)
# ============================================================
# 2 private subnets (one per AZ)
# 2 NAT Gateways (one per AZ) → no cross-AZ dependency!
# 2 private route tables (each points to own NAT GW)
# ============================================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                         = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }
}

# ── 2 Elastic IPs (one per NAT Gateway) ──────────────────────
resource "aws_eip" "nat" {
  count      = 2
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip-${count.index + 1}"
  }
}

# ── 2 NAT Gateways (one per AZ) ──────────────────────────────
# AZ1 NAT GW → serves AZ1 private subnet
# AZ2 NAT GW → serves AZ2 private subnet
# If AZ1 goes down → AZ2 completely unaffected! ✅
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project}-${var.environment}-nat-gw-${count.index + 1}"
  }
}

# ── 2 Private Route Tables (one per AZ) ──────────────────────
# Each AZ has its OWN route table pointing to its OWN NAT GW
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

# ── Associate each private subnet with its OWN route table ───
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
