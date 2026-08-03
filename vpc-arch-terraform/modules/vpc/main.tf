# ─────────────────────────────────────────────────────────────────────────────
# VPC MODULE — re-creates the Week 1 network layer using Terraform
#
# What this module provisions (in order of dependency):
#   VPC → Subnets → IGW → EIP → NAT → Route Tables → RT Associations
#
# Terraform concept: resources inside a module are isolated — the root config
# calls this module via source = "./modules/vpc" and receives outputs.
# ─────────────────────────────────────────────────────────────────────────────

# ── 1. VPC ────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required so EC2s get resolvable hostnames
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ── 2. Public Subnets ─────────────────────────────────────────────────────────
# count meta-argument creates one resource per element in the list.
# count.index is the loop index (0, 1, …).
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Instances launched here automatically get a public IP — key for Bastion Host
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier    = "Public"
    Project = var.project_name
  }
}

# ── 3. Private Subnets ────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # No public IP — private EC2s are only reachable via Bastion
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier    = "Private"
    Project = var.project_name
  }
}

# ── 4. Internet Gateway ───────────────────────────────────────────────────────
# Without this, public subnets cannot reach the internet even with public IPs.
# A subnet is only "public" when its route table has 0.0.0.0/0 → IGW.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ── 5. Elastic IP for NAT Gateway ─────────────────────────────────────────────
# The NAT gateway needs a static public IP so private EC2 outbound traffic
# appears to come from a known address.
# count = 0 when enable_nat_gateway = false → no resource created, costs ₹0
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  # EIP must be created after IGW exists
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

# ── 6. NAT Gateway ────────────────────────────────────────────────────────────
# Placed in a PUBLIC subnet (has internet via IGW).
# Private subnet route table points 0.0.0.0/0 → NAT.
# Result: private EC2 can reach internet (git clone, dnf update),
#         but internet CANNOT initiate connections to private EC2.
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id # Must live in a public subnet

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }
}

# ── 7. Public Route Table ─────────────────────────────────────────────────────
# All traffic not destined for the VPC (0.0.0.0/0) goes to the IGW.
# The local route (10.0.0.0/16 → local) is implicit — Terraform adds it automatically.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# Associate BOTH public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── 8. Private Route Table ────────────────────────────────────────────────────
# When enable_nat_gateway = true:  0.0.0.0/0 → NAT  (outbound internet via NAT)
# When enable_nat_gateway = false: no default route  (fully isolated — great for study)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # dynamic block: conditionally add the NAT route only when NAT exists
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

# Associate BOTH private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
