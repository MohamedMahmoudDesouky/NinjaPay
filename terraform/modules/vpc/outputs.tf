output "vpc_id" {
  value = aws_vpc.prod.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_app_subnets" {
  value = [for s in aws_subnet.private_app : s.id]
}

output "private_db_subnets" {
  value = [for s in aws_subnet.private_db : s.id]
}

output "vpc_cidr" {
  value = aws_vpc.prod.cidr_block
}