# ==============================================================================
# Terraform Providers Configuration
# Project: 01-jenkins-ci-cd
# ==============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "01-jenkins-ci-cd"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
