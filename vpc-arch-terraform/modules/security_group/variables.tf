variable "project_name" {
  description = "Prefix for all security group names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "my_ip" {
  description = "Your public IP with CIDR (e.g. 203.0.113.10/32). Only this IP can SSH to Bastion"
  type        = string
  sensitive   = true # Prevents IP from appearing in Terraform logs
}
