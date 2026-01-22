# VPC Module - Production Network
resource "aws_vpc" "prod" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-prod-vpc" }
  )
}

# Get AZs dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Public Subnets (for NAT GW, ALB)
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 1)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-az-${each.value.suffix}"
      Tier = "public"
    }
  )
}

# Private App Subnets (for ECS)
resource "aws_subnet" "private_app" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 11)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-app-az-${each.value.suffix}"
      Tier = "private-app"
    }
  )
}

# Database Subnets (for RDS/Aurora)
resource "aws_subnet" "private_db" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 21)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-db-az-${each.value.suffix}"
      Tier = "private-db"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod.id

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-igw" }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-public-rt" }
  )
}

# Associate public subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateways (one per AZ for HA)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-nat-eip-${each.key}" }
  )
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-nat-gw-${each.key}" }
  )
}

# Private Route Table (for app & DB subnets)
resource "aws_route_table" "private" {
  for_each = aws_subnet.public

  vpc_id = aws_vpc.prod.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-private-rt-az-${["a", "b"][each.key]}" }
  )
}

# Associate private app subnets to corresponding NAT
resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Associate database subnets to corresponding NAT
resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# VPC Endpoints
# Gateway Endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.prod.id
  service_name    = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [for rt in aws_route_table.private : rt.id]
  tags = merge(var.tags, { Name = "${var.project_name}-s3-vpce" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = aws_vpc.prod.id
  service_name    = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [for rt in aws_route_table.private : rt.id]
  tags = merge(var.tags, { Name = "${var.project_name}-dynamodb-vpce" })
}

# Interface Endpoints (SSM, ECR, Secrets Manager)
resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-vpce-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.prod.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "ssm",
    "ssmmessages"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_services)

  vpc_id             = aws_vpc.prod.id
  service_name       = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for s in aws_subnet.private_app : s.id]
  security_group_ids = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-${each.value}-vpce" }
  )
}