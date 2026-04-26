# Terraform + AWS VPC Interview Questions (Project 2)

## 1) What is Terraform state and why is it important?
Terraform state (`terraform.tfstate`) maps resources in code to real AWS resource IDs.  
Without state, Terraform cannot safely plan updates or destroy the correct resources.

## 2) Difference between `terraform plan` and `terraform apply`?
- `plan`: preview only, no changes
- `apply`: executes changes in AWS

## 3) Why use variables in Terraform?
Variables make code reusable and environment-friendly (dev/stage/prod with different values).

## 4) What is a data source in Terraform?
A data source reads existing information from provider APIs.  
In this project, `data.aws_ami.amazon_linux_2023` fetches the latest AMI.

## 5) How does Terraform know creation order?
Terraform builds a dependency graph from references like `aws_vpc.main.id`.

## 6) What happens if I delete a resource manually in AWS console?
Next `terraform plan` will detect drift and try to recreate or reconcile depending on config/state.

## 7) Why is `create_ec2` implemented with `count`?
It allows optional creation:
- `false` -> `count = 0` (no instance)
- `true` -> `count = 1` (one instance)

## 8) What makes a subnet public?
A subnet is public when its route table has `0.0.0.0/0` pointing to an Internet Gateway.

## 9) Why keep no inbound rules in the security group?
Safe default for learning and cost/security control. It blocks direct inbound access.

## 10) Difference between `terraform validate` and `terraform fmt`?
- `validate`: checks syntax and semantic validity
- `fmt`: formats Terraform code style

## 11) How would you separate dev and prod in Terraform?
Use separate variable files, remote state per environment, and often separate AWS accounts.

## 12) Why use remote backend in team projects?
To share state centrally, prevent conflicts, and enable state locking.

## 13) What is drift in Terraform?
Drift is when real infrastructure differs from Terraform state/code due to manual or external changes.

## 14) Why avoid hardcoding AMI IDs?
AMI IDs differ by region and become outdated; data source lookup is safer and portable.

## 15) What are common production improvements from this project?
- Multi-AZ subnets
- NAT + private subnets for app/database
- ALB + autoscaling
- Remote state backend
- CI/CD pipeline with Terraform checks
