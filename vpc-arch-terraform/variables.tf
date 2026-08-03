# ─────────────────────────────────────────────────────────────────────────────
# ROOT VARIABLES
#
# Variables make your config reusable and separate WHAT from HOW.
# Actual values come from terraform.tfvars (never hardcoded here).
# Sensitive variables (my_ip, key_name) are marked sensitive = true
# so they don't appear in terraform plan output.
# ─────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Short name prefix used in all resource tags and names (e.g. vpc-week2)"
  type        = string
  default     = "vpc-week2"
}

variable "aws_region" {
  description = "AWS region to deploy into. ap-south-1 = Mumbai"
  type        = string
  default     = "ap-south-1"
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR for the entire VPC. /16 gives 65,536 addresses — standard for a project VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Each /24 gives 256 addresses per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "azs" {
  description = "Availability Zones — must have same count as subnet CIDR lists"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Toggle NAT Gateway creation.
    true  = full architecture (private EC2 can reach internet for git/dnf)
    false = no NAT, saves ~₹3.75/hr — use when only studying Terraform syntax
  EOT
  type        = bool
  default     = true
}

# ── Compute ────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type. t2.micro is Free Tier eligible (750 hrs/month)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 Key Pair in your AWS account. Create one at EC2 → Key Pairs first"
  type        = string
  sensitive   = true
}

# ── Security ───────────────────────────────────────────────────────────────────

variable "my_ip" {
  description = <<-EOT
    Your public IP with /32 CIDR (e.g. 203.0.113.45/32).
    Find it: curl https://checkip.amazonaws.com
    Only this IP can SSH to the Bastion Host.
  EOT
  type        = string
  sensitive   = true # Keeps your IP out of plan/apply output
}
