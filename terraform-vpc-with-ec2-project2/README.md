# Terraform VPC with Optional EC2 (Free-Tier Focus)

> **Difficulty:** Beginner | **Cost:** Near-zero by default | **Type:** Infrastructure as Code (Terraform + AWS)

This project builds a basic AWS network architecture using Terraform in a safe and cost-aware way.  
You get a VPC, subnet, internet routing, and security group, and you can optionally launch one EC2 instance when needed.

---

## What This Project Covers

| Area | What You Build |
|------|----------------|
| **Terraform Basics** | Providers, variables, resources, data sources, outputs |
| **Networking** | Custom VPC, one subnet, route table, internet gateway |
| **Security** | Security group with safe default (no inbound rules) |
| **Compute (Optional)** | One EC2 instance controlled by `create_ec2` |
| **Cost Control** | "No EC2 by default" and clean destroy workflow |

---

## Architecture Overview

```text
          Internet
              |
          [ IGW ]
              |
     [ Route Table: 0.0.0.0/0 -> IGW ]
              |
        [ Public Subnet ]
              |
      [ Optional EC2: count = 0/1 ]
              |
             [ SG ]
```

### Connection Flow

1. VPC is created.
2. Subnet is created inside that VPC.
3. Internet Gateway is attached to VPC.
4. Route table sends internet traffic (`0.0.0.0/0`) to IGW.
5. Route table is associated with subnet.
6. Security group is created in same VPC.
7. Latest AMI is fetched dynamically via data source.
8. EC2 is created only if `create_ec2 = true`.

---

## Terraform Execution Flow (Init -> Plan -> Apply)

### 1) `terraform init`
- Downloads AWS provider plugins
- Initializes `.terraform/` working directory
- No AWS resources are created

### 2) `terraform plan`
- Reads desired state from `.tf` files
- Reads current state from state file + AWS
- Shows what will be created/changed/destroyed
- No resources are changed

### 3) `terraform apply`
- Executes the plan in dependency order
- Creates/updates resources in AWS
- Writes real IDs into `terraform.tfstate`

---

## Prerequisites

- AWS account
- IAM user access key + secret key
- AWS CLI configured: `aws configure`
- Terraform CLI installed

---

## Usage

```bash
terraform init
terraform plan
terraform apply
```

Default behavior: `create_ec2 = false`, so only networking resources are created.

### Enable one EC2 later

Edit `variables.tf`:

```hcl
create_ec2    = true
instance_type = "t2.micro"
```

Then run:

```bash
terraform plan
terraform apply
```

---

## Cost and Safety Notes

- Free tier is not always strictly zero cost in every account/region.
- Public IPv4, EBS, data transfer, and long-running resources may generate charges.
- This project avoids ALB/NAT/S3 by default to reduce cost risk.

---

## Common Debug Commands

```bash
terraform fmt
terraform validate
terraform plan
terraform state list
terraform state show aws_vpc.main
terraform output
```

For full troubleshooting scenarios, see `TERRAFORM-DEBUGGING.md`.

---

## Project Structure

```text
terraform-vpc-with-ec2-project2/
├── README.md
├── WHAT-YOU-WILL-LEARN.md
├── provider.tf
├── variables.tf
├── main.tf
├── INTERVIEW-QUESTIONS.md
└── TERRAFORM-DEBUGGING.md
```

---

## Cleanup

Always clean resources after practice:

```bash
terraform destroy
```

---

*Author: Hiten Jaypal | Stack: Terraform + AWS VPC + EC2*
