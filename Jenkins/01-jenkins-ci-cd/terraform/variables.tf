# ==============================================================================
# Input Variables
# Project: 01-jenkins-ci-cd
# ==============================================================================

variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier eligible: t2.micro or t3.micro)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing AWS Key Pair for SSH access (optional)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_docker_host" {
  description = "Whether to create a separate Docker Host EC2 instance (set false to run on a single EC2 for cost savings)"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Optional existing VPC ID. If empty, the default VPC will be used."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Optional existing Subnet ID. If empty, a subnet from the VPC will be selected."
  type        = string
  default     = ""
}
