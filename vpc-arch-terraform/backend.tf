# ─────────────────────────────────────────────────────────────────────────────
# REMOTE STATE BACKEND (S3 + DynamoDB)
#
# By default Terraform stores state locally in terraform.tfstate.
# Problem: if you lose that file you lose track of all resources Terraform manages.
#
# Solution — S3 backend:
#   • State stored safely in S3 (survives laptop crashes)
#   • Versioning on the bucket = full history of every apply
#   • DynamoDB table = state locking (prevents two people running apply at once)
#
# ⚠️  PREREQUISITE: You MUST create the S3 bucket and DynamoDB table MANUALLY
#     BEFORE running `terraform init` with this backend block.
#     Run the commands below in AWS CloudShell or your terminal first.
#
# Step 1 — Create S3 bucket (replace YOUR-NAME with something unique globally):
#   aws s3 mb s3://hiten-tfstate-vpc-week2 --region ap-south-1
#   aws s3api put-bucket-versioning \
#     --bucket hiten-tfstate-vpc-week2 \
#     --versioning-configuration Status=Enabled
#   aws s3api put-public-access-block \
#     --bucket hiten-tfstate-vpc-week2 \
#     --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
#
# Step 2 — Create DynamoDB table for state locking:
#   aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-south-1
#
# Step 3 — Uncomment the block below (replace bucket name), then run: terraform init
# ─────────────────────────────────────────────────────────────────────────────

#terraform {
#  backend "s3" {
#    bucket         = "hiten-tfstate-vpc-week2"
#    key            = "vpc-arch-terraform/terraform.tfstate"
#    region         = "ap-south-1"
#    dynamodb_table = "terraform-state-lock"
#    encrypt        = true
#  }
#}
