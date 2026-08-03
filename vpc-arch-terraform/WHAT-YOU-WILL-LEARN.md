# What You Will Learn in This Project (Week 2 — Modules)

> This project upgrades the Week 1 manual VPC build into a **modular Terraform** codebase.
> Each concept below maps to a real file in this repo so you can read the source, not just theory.

---

## Terraform Foundations (Level-Up from Week 1)

- `terraform {}` block, `required_version`, and `required_providers` pinning → `provider.tf`
- `provider "aws"` with `default_tags` to auto-tag every resource → `provider.tf`
- Root variables with `type`, `description`, `default`, and `sensitive = true` → `variables.tf`
- Separating config from code using `terraform.tfvars` → `terraform.tfvars`
- Exposing values after `apply` with `output` blocks → `outputs.tf`, `modules/*/outputs.tf`

## Terraform Modules (Core Week 2 Skill)

- What a module is and why we split infrastructure into `modules/<name>/`
- Calling a module with `module "<label>" { source = "./modules/<folder>" ... }` → `main.tf`
- Passing inputs into a module (variable mapping)
- Reading outputs from a module (`module.vpc.vpc_id`, `module.vpc.public_subnet_ids[0]`) → `main.tf`
- Cross-module dependency wiring (VPC → Security Group → EC2) → `main.tf`

## Meta-Arguments & Expressions

- `count` to loop-create multiple subnets from a list → `modules/vpc/main.tf`
- `count.index` to pick CIDR/AZ per iteration → `modules/vpc/main.tf`
- Conditional count: `count = var.enable_nat_gateway ? 1 : 0` to toggle NAT/EIP → `modules/vpc/main.tf`
- `dynamic "route"` block to conditionally insert a route only when NAT exists → `modules/vpc/main.tf`
- `[*]` splat expression to collect all subnet IDs into a list → `modules/vpc/outputs.tf`
- `depends_on` for explicit resource dependency on IGW (EIP/NAT) → `modules/vpc/main.tf`

## Data Sources vs Resources

- `data "aws_ami"` — reads the latest Amazon Linux 2023 AMI without creating anything → `modules/ec2/main.tf`
- Why dynamic AMI lookup beats hardcoding AMI IDs (region/time portability)
- Difference between a `resource` (creates) and a `data` block (reads) → `modules/ec2/main.tf`

## AWS Networking (Production-Shaped)

- VPC with custom CIDR (`10.0.0.0/16`) and DNS hostnames/support enabled → `modules/vpc/main.tf`
- Multi-AZ public + private subnets (`map_public_ip_on_launch` true/false) → `modules/vpc/main.tf`
- Internet Gateway and what actually makes a subnet "public" (route `0.0.0.0/0 → IGW`) → `modules/vpc/main.tf`
- NAT Gateway + Elastic IP in a public subnet for private egress → `modules/vpc/main.tf`
- Separate public vs private route tables and subnet associations → `modules/vpc/main.tf`

## Security & Access Patterns

- Security Groups are **stateful** — no separate egress needed for allowed inbound → `modules/security_group/main.tf`
- Least-privilege Bastion SG: SSH only from `my_ip` → `modules/security_group/main.tf`
- SG-to-SG referencing (private EC2 allows SSH from Bastion SG ID, not IP) → `modules/security_group/main.tf`
- Why SG references survive Bastion IP changes (vs brittle IP-based rules)
- `sensitive = true` on `my_ip` and `key_name` to hide them from plan output → `variables.tf`

## Compute & Bootstrapping

- Bastion Host (jump server) in the public subnet with a public IP → `modules/ec2/main.tf`
- Private Dev Server with no public IP, reachable only via Bastion → `modules/ec2/main.tf`
- `user_data` bootstrap script to install + start Nginx and deploy a web page on first boot → `modules/ec2/main.tf`
- Two-hop SSH path: local → Bastion → private Dev Server → described in `outputs.tf`

## Remote State & Team Workflows

- Why local `terraform.tfstate` is risky (laptop crash = lost track of resources) → `backend.tf`
- S3 backend for safe, versioned state storage → `backend.tf`
- DynamoDB state locking to prevent concurrent `apply` corruption → `backend.tf`
- Manual prerequisites (bucket + table) before `terraform init` with a backend → `backend.tf`

## Cost-Aware Engineering

- `enable_nat_gateway` toggle to skip ₹3.75/hr NAT during pure syntax study → `variables.tf`
- Free-tier `t2.micro` instances and ₹0 VPC/SG/RT resources → `variables.tf`
- Discipline of `terraform destroy` after every session → README Phase 5

## Infrastructure Workflow

- `init → validate → plan → apply → destroy` end-to-end → README
- Reading `plan` output carefully before every `apply`
- Understanding Terraform state as the "memory" between runs → README
- Detecting drift when AWS console changes diverge from state

## Interview Readiness

- Module design, `count`/`dynamic`, NAT vs IGW, bastion pattern, data sources, remote state
- Real debugging scenarios from this stack → see `TERRAFORM-DEBUGGING.md`
- Conceptual Q&A with source-file references → see `INTERVIEW-QUESTIONS.md`

---

*Concept → File mapping is the fastest way to learn. Open each file mentioned above alongside this doc.*