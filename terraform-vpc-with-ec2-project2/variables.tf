variable "cidr" {
  default = "10.0.0.0/16"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "project_name" {
  description = "Name prefix used for tags"
  type        = string
  default     = "free-vpc-ec2"
}

variable "create_ec2" {
  description = "Set true only when you want to launch 1 free-tier instance"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Free-tier eligible instance type"
  type        = string
  default     = "t2.micro"
}