variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "public_subnet_id" {
  description = "Subnet ID for Bastion Host (must be a public subnet)"
  type        = string
}

variable "private_subnet_id" {
  description = "Subnet ID for Dev Server (must be a private subnet)"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security Group ID for the Bastion Host"
  type        = string
}

variable "private_ec2_sg_id" {
  description = "Security Group ID for the Private Dev Server"
  type        = string
}

variable "key_name" {
  description = "Name of the existing EC2 Key Pair (must already exist in AWS — not created by Terraform)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro is Free Tier eligible"
  type        = string
  default     = "t2.micro"
}
