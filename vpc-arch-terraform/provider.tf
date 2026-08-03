# ─────────────────────────────────────────────────────────────────────────────
# PROVIDER CONFIGURATION
#
# terraform {} block: declares the Terraform version and required providers.
#   required_version: ensures everyone on the team uses a compatible version.
#   required_providers: pins the AWS provider version (~> 5.0 = any 5.x release).
#
# provider "aws" {}: tells Terraform HOW to talk to AWS.
#   region is pulled from var.aws_region, defined in variables.tf.
#   Credentials come from ~/.aws/credentials or environment variables —
#   NEVER hardcode access_key / secret_key in .tf files.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Optional: tag every resource Terraform creates with a common owner tag.
  # Useful in shared AWS accounts so you know who created what.
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Week      = "Week2"
    }
  }
}
