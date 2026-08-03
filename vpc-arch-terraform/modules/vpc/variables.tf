variable "project_name" {
  description = "Prefix used for naming all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC (e.g. 10.0.0.0/16)"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets — one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets — one per AZ"
  type        = list(string)
}

variable "azs" {
  description = "Availability Zones to deploy subnets into (must match length of subnet CIDR lists)"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway. Set false to skip NAT and save ~₹3.75/hr during study"
  type        = bool
  default     = true
}
