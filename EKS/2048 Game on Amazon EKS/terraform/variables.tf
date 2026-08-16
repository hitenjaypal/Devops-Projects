variable "aws_region" {
  description = "AWS Region for the VPC. Use the same Region for the manual EKS cluster."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for the VPC and security-group names."
  type        = string
  default     = "2048-eks"
}

variable "vpc_cidr" {
  description = "IPv4 address range for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "cluster_name" {
  description = "The cluster name you will create manually in the EKS console. Used for subnet tags."
  type        = string
  default     = "2048-eks-cluster"
}

variable "admin_cidr" {
  description = "Your current public IPv4 address in CIDR form, for example 203.0.113.10/32."
  type        = string
}
