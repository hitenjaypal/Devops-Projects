output "bastion_sg_id" {
  description = "Bastion Host security group ID — passed to EC2 module and used as source in private-ec2-sg"
  value       = aws_security_group.bastion.id
}

output "private_ec2_sg_id" {
  description = "Private EC2 security group ID"
  value       = aws_security_group.private_ec2.id
}
