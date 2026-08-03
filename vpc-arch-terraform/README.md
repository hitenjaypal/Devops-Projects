# Terraform VPC Architecture — Week 2 (Modules)

> **Week:** 2 | **Stack:** Terraform + AWS VPC + EC2 + NAT + Nginx | **Region:** ap-south-1
> **Goal:** Re-create the Week 1 VPC architecture using Terraform modules — the industry-standard way to write IaC.

---

## What This Project Does

This project takes everything you built manually in Week 1 (click-by-click in the AWS Console) and converts it into **reusable, version-controlled Terraform code**.

**Same architecture. Zero console clicks.**

```
                      ┌──────────────────────────────────────────────────────┐
                      │              VPC: 10.0.0.0/16                        │
                      │                                                      │
  INTERNET            │  ┌────────────────────┐  ┌──────────────────────┐   │
     │                │  │  PUBLIC SUBNET 1   │  │  PUBLIC SUBNET 2     │   │
     │                │  │  10.0.1.0/24 (AZ-a)│  │  10.0.2.0/24 (AZ-b) │   │
     ▼                │  │                    │  │                      │   │
[Internet Gateway]────┼─►│  [Bastion Host]    │  │  [NAT Gateway]       │   │
                      │  │   t2.micro         │  │  + Elastic IP        │   │
                      │  │   Public IP ✅     │  │                      │   │
                      │  └────────┬───────────┘  └────────┬─────────────┘   │
                      │           │ SSH (22)               │ Outbound only   │
                      │           ▼                        ▼                 │
                      │  ┌────────────────────┐  ┌──────────────────────┐   │
                      │  │  PRIVATE SUBNET 1  │  │  PRIVATE SUBNET 2    │   │
                      │  │  10.0.3.0/24 (AZ-a)│  │  10.0.4.0/24 (AZ-b) │   │
                      │  │                    │  │                      │   │
                      │  │  [Dev Server]      │  │  (Reserved)          │   │
                      │  │   Nginx + Web App  │  │                      │   │
                      │  │   No public IP ❌  │  │                      │   │
                      │  └────────────────────┘  └──────────────────────┘   │
                      │                                                      │
                      │  Public RT:  0.0.0.0/0 → IGW                        │
                      │  Private RT: 0.0.0.0/0 → NAT Gateway                │
                      └──────────────────────────────────────────────────────┘
```

---

## Project Structure

```
vpc-arch-terraform/
├── provider.tf          ← p + Terraform version constraints
├── backend.tf           ← S3 remote state config (read instructions inside!)
├── main.tf              ← Calls all three modules
├── variables.tf         ← Variable declarations with descriptions
├── outputs.tf           ← Exposes IPs, IDs, ready-to-use SSH commands
├── terraform.tfvars     ← Your actual values (fill in key_name and my_ip)
└── modules/
    ├── vpc/             ← VPC, subnets, IGW, NAT, route tables
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security_group/  ← Bastion SG + Private EC2 SG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2/             ← Bastion Host + Dev Server (Nginx via user_data)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Terraform Concepts You Will Learn (with Where to Find Them)


| Concept                | File to Read                         | What It Teaches                      |
| ---------------------- | ------------------------------------ | ------------------------------------ |
| `terraform {}` block   | `provider.tf`                        | Version pinning, required providers  |
| `provider "aws"`       | `provider.tf`                        | How Terraform connects to AWS        |
| `variable` + `default` | `variables.tf`                       | Input variables, types, descriptions |
| `terraform.tfvars`     | `terraform.tfvars`                   | Separating config from code          |
| `module` block         | `main.tf`                            | Calling modules, passing inputs      |
| `module.vpc.vpc_id`    | `main.tf`                            | Cross-module references via outputs  |
| `output`               | `outputs.tf`, `modules/*/outputs.tf` | Exposing values after apply          |
| `count` meta-argument  | `modules/vpc/main.tf`                | Looping to create multiple subnets   |
| `count.index`          | `modules/vpc/main.tf`                | Accessing loop index                 |
| `[*]` splat expression | `modules/vpc/outputs.tf`             | Collecting all IDs into a list       |
| `dynamic` block        | `modules/vpc/main.tf`                | Conditional route in private RT      |
| `depends_on`           | `modules/vpc/main.tf`                | Explicit resource dependency         |
| `data "aws_ami"`       | `modules/ec2/main.tf`                | Data sources — read without creating |
| `user_data`            | `modules/ec2/main.tf`                | Bootstrap script on first boot       |
| `sensitive = true`     | `variables.tf`                       | Hiding values from plan output       |
| `backend "s3"`         | `backend.tf`                         | Remote state with S3 + DynamoDB lock |


---

## Step-by-Step: How to Run This Project

### Prerequisites

```bash
# 1. Install Terraform (Windows — run in PowerShell as Admin)
winget install HashiCorp.Terraform

# Verify
terraform -version   # Should show >= 1.5.0

# 2. Configure AWS CLI
aws configure
# Enter: Access Key, Secret Key, region=ap-south-1, output=json

# 3. Verify AWS access
aws sts get-caller-identity
```

---

### Phase 1 — Prepare terraform.tfvars

```bash
# Find your public IP
curl https://checkip.amazonaws.com
# Example output: 203.0.113.45
# Your my_ip value will be: 203.0.113.45/32
```

Open `terraform.tfvars` and fill in:

```hcl
key_name = "your-actual-key-pair-name"   # Must exist in EC2 → Key Pairs
my_ip    = "203.0.113.45/32"             # Your IP from above
```

> **Create a key pair if you don't have one:**
> EC2 Console → Key Pairs → Create key pair → Name it `hiten-week2-key` → Download `.pem`

---

### Phase 2 — (Optional but Recommended) Set Up Remote State

Follow the instructions in `backend.tf` to create the S3 bucket and DynamoDB table, then uncomment the backend block.

**Skip this step** if you just want to run locally for study — local state works fine.

---

### Phase 3 — Terraform Workflow

```bash
# Navigate to the project
cd vpc-arch-terraform

# Step 1: terraform init
# Downloads the AWS provider plugin, sets up modules, initializes backend
terraform init

# Step 2: terraform validate
# Catches syntax errors BEFORE hitting AWS — fast, free
terraform validate

# Step 3: terraform plan
# Shows EXACTLY what will be created/changed/destroyed — no AWS resources yet
# Read this carefully before every apply!
terraform plan

# Step 4: terraform apply
# Creates all resources. Type "yes" when prompted.
# Takes ~3-4 minutes (NAT Gateway is the slowest)
terraform apply

# After apply, outputs are printed automatically:
# bastion_public_ip     = "x.x.x.x"
# dev_server_private_ip = "10.0.3.x"
# step1_ssh_to_bastion  = "ssh -i ..."
```

---

### Phase 4 — Verify the Architecture

```bash
# 1. SSH into Bastion (copy the step1_ssh_to_bastion output)
ssh -i ~/.ssh/your-key.pem ec2-user@<BASTION-PUBLIC-IP>

# 2. From Bastion: SSH into Dev Server
ssh -i ~/.ssh/your-key.pem ec2-user@<DEV-SERVER-PRIVATE-IP>

# 3. From Dev Server: verify internet access via NAT
curl https://checkip.amazonaws.com   # Returns NAT Gateway's public IP, not your IP

# 4. Verify Nginx is running
sudo systemctl status nginx
curl http://localhost   # Returns the HTML page deployed by Terraform
```

---

### Phase 5 — ALWAYS Destroy After Each Session

```bash
# Costs ₹0 to have Terraform code sitting on your laptop.
# Costs money every hour the NAT Gateway and EC2s are running.
terraform destroy

# Verify nothing is still running
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0]]" \
  --output table
```

---

## Cost Guide


| Resource                        | Cost          | Notes                                       |
| ------------------------------- | ------------- | ------------------------------------------- |
| VPC, Subnets, IGW, Route Tables | ₹0            | Always free                                 |
| Security Groups                 | ₹0            | Always free                                 |
| t2.micro EC2 (x2)               | ₹0            | Free Tier: 750 hrs/month                    |
| S3 state bucket                 | ~₹0           | State files are <1MB                        |
| DynamoDB lock table             | ₹0            | Free Tier: 25 WCU/RCU                       |
| **NAT Gateway**                 | **~₹3.75/hr** | Only real cost — destroy after each session |


**Target cost: ₹0** if you run `terraform destroy` every session.

> **Cost hack:** Set `enable_nat_gateway = false` in `terraform.tfvars` while just studying Terraform syntax. The whole architecture deploys except NAT — saving ₹3.75/hr. Set it back to `true` only when you need private EC2 internet access.

---

## Key Concepts: Week 1 vs Week 2


| Week 1 (Manual)                     | Week 2 (Terraform)              | What You Gain                  |
| ----------------------------------- | ------------------------------- | ------------------------------ |
| Click "Create VPC" in Console       | `resource "aws_vpc" "main" {}`  | Version control, repeatability |
| Manually pick AMI from dropdown     | `data "aws_ami" {}` filter      | Dynamic, never stale           |
| Click subnet in each AZ             | `count = length(var.azs)`       | One block creates N subnets    |
| Edit route table in Console         | `resource "aws_route_table" {}` | Auditable, diff-able           |
| SSH key: download and remember path | `key_name = var.key_name`       | Parameterized                  |
| Cleanup: click through 8 steps      | `terraform destroy`             | One command, complete teardown |
| If you forget a step: broken arch   | `terraform plan` shows gaps     | Declarative safety net         |


---

## Terraform State — What It Is and Why It Matters

```
terraform.tfstate is Terraform's memory.

After terraform apply:
  Terraform writes a JSON file recording every resource it created,
  including their IDs, IPs, and dependencies.

Before every plan/apply:
  Terraform reads the state file to know what already exists,
  then compares it to your .tf files to calculate the diff.

If you delete the state file:
  Terraform loses track of your resources.
  The resources still exist in AWS, but Terraform doesn't know about them.
  You would have to import them or start over.

Remote state (S3):
  Stores the state file in S3 instead of locally.
  DynamoDB lock prevents two people from running apply simultaneously
  (preventing race conditions that corrupt state).
```

---

## Troubleshooting


| Error                                      | Cause                                                          | Fix                                                               |
| ------------------------------------------ | -------------------------------------------------------------- | ----------------------------------------------------------------- |
| `Error: No valid credential sources found` | AWS CLI not configured                                         | Run `aws configure`                                               |
| `InvalidKeyPair.NotFound`                  | Key pair doesn't exist in ap-south-1                           | Create key pair in EC2 Console                                    |
| `Error acquiring the state lock`           | Previous apply crashed mid-run                                 | `terraform force-unlock <LOCK-ID>`                                |
| `InvalidAMIID.NotFound`                    | AMI filter returned nothing                                    | The data source filters are correct for al2023; check your region |
| SSH timeout to Bastion                     | Your IP changed since apply                                    | Update `my_ip` in tfvars, run `terraform apply` again             |
| `Error: Backend initialization required`   | Backend block changed                                          | Run `terraform init -reconfigure`                                 |
| Nginx not responding                       | user_data still running (takes ~2 min after instance is ready) | Wait 2 minutes then retry                                         |


---

## What to Try Next (Week 2 Extension Exercises)

1. **Add a workspace:** `terraform workspace new staging` — deploy a second isolated copy
2. **Add locals:** Create a `locals.tf` with `common_tags = { Project = var.project_name }` and use it everywhere
3. **Add an ALB module:** Create `modules/alb/` that puts a load balancer in front of the Dev Server
4. **Parameterize instance count:** Add `variable "dev_server_count"` and use `count` in the EC2 module
5. **Import existing resources:** If you have leftover Week 1 manual resources: `terraform import aws_vpc.main <vpc-id>`

---

*Week 2 of Hiten Jaypal's 12-Week DevOps Learning Journey | Terraform + AWS VPC | ap-south-1*