output "bastion_public_ip" {
  description = "Public IP of the Bastion Host — use this to SSH in from your machine"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the Bastion Host"
  value       = aws_instance.bastion.id
}

output "dev_server_private_ip" {
  description = "Private IP of the Dev Server — SSH to this from inside the Bastion"
  value       = aws_instance.dev_server.private_ip
}

output "dev_server_instance_id" {
  description = "Instance ID of the Dev Server"
  value       = aws_instance.dev_server.id
}

output "ami_id_used" {
  description = "The AMI ID that was resolved by the data source (useful for debugging)"
  value       = data.aws_ami.amazon_linux_2023.id
}
