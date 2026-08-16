output "vpc_id" {
  description = "Select this VPC in the EKS console."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Use for public load balancers."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Select these private subnets for the manual node group."
  value       = aws_subnet.private[*].id
}

output "eks_api_security_group_id" {
  description = "Select this as an additional security group during manual EKS cluster creation."
  value       = aws_security_group.eks_api.id
}
