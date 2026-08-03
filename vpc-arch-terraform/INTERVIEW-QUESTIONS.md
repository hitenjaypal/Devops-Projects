# Terraform + AWS VPC Interview Questions (Week 2 — Modules)

> Answers reference the actual files in this repo so you can explain *why*, not just recite.
> Source locations are noted like `file.tf` so you can prep with the code open.

---

## Modules & Structure

### 1) What is a Terraform module and why use one?
A module is a self-contained set of `.tf` files (usually `main.tf`, `variables.tf`, `outputs.tf`) you call from elsewhere.
Benefits: reuse, separation of concerns, readability, and version control of logical chunks.
See `modules/vpc/`, `modules/security_group/`, `modules/ec2/` in this project.

### 2) How do you call a local module and pass inputs?
```hcl
module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}
```
See `main.tf`. After editing `source`, you must run `terraform init` so Terraform installs the module.

### 3) How do modules share data with each other?
A module exposes values via `output` blocks (`modules/vpc/outputs.tf`).
The root config reads them as `module.vpc.vpc_id`, `module.vpc.public_subnet_ids[0]`, etc., and passes them into the next module.
See the wiring in `main.tf` (VPC → SG → EC2).

### 4) Should variables be defined in the root or in modules?
Both. Module-level variables (`modules/vpc/variables.tf`) accept inputs *into* the module.
Root-level variables (`variables.tf`) accept inputs from `terraform.tfvars` and feed them into module calls.
Avoid hardcoding inside modules — that kills reuse.

---

## Meta-Arguments: `count`, `dynamic`, `depends_on`

### 5) How does `count` create multiple subnets here?
```hcl
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
}
```
One list entry → one subnet. `count.index` selects the right CIDR and AZ per iteration.
See `modules/vpc/main.tf`.

### 6) How do you conditionally create a resource with `count`?
```hcl
count = var.enable_nat_gateway ? 1 : 0
```
`0` means the resource is not created at all. Used for the EIP and NAT Gateway.
See `modules/vpc/main.tf`. This is how `enable_nat_gateway = false` saves cost.

### 7) What is a `dynamic` block and where is it used?
A `dynamic` block generates nested blocks based on a list/condition.
Here it conditionally adds the `0.0.0.0/0 → NAT` route only when NAT exists:
```hcl
dynamic "route" {
  for_each = var.enable_nat_gateway ? [1] : []
  content {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
}
```
See `modules/vpc/main.tf`.

### 8) What is the `[*]` / splat expression?
`aws_subnet.public[*].id` collects the IDs of every subnet created by `count` into a list.
See `modules/vpc/outputs.tf`. The root then indexes it like `module.vpc.public_subnet_ids[0]`.

### 9) When would you use `depends_on` vs implicit dependencies?
Terraform usually infers order from references (e.g., `vpc_id = aws_vpc.main.id`).
Use `depends_on` when there's *no direct reference* but a real ordering need.
Here the EIP and NAT Gateway use `depends_on = [aws_internet_gateway.main]` so the IGW exists first.
See `modules/vpc/main.tf`.

---

## VPC & Networking Concepts

### 10) What does a `/16` VPC CIDR give you?
65,536 addresses (minus AWS-reserved ones). This project uses `10.0.0.0/16` with `/24` subnets (256 addresses each).
See `variables.tf`.

### 11) What actually makes a subnet "public"?
Not a flag — it's the **route table**: a `0.0.0.0/0` route pointing to an Internet Gateway.
The public route table here routes `0.0.0.0/0 → IGW`; the private one routes to NAT (or nothing).
See `modules/vpc/main.tf`.

### 12) Why is the NAT Gateway in a public subnet?
NAT needs internet access via the IGW to forward private-subnet traffic out.
If it sat in a private subnet it couldn't reach the internet at all.
See `modules/vpc/main.tf` (`subnet_id = aws_subnet.public[0].id`).

### 13) Can the internet reach the private Dev Server?
No. Private subnet has `map_public_ip_on_launch = false`, no `0.0.0.0/0 → IGW` route, and the SG only allows SSH from the Bastion SG.
The Dev Server can reach *out* (via NAT) but nothing can initiate inbound from the internet.
See `modules/vpc/main.tf` and `modules/security_group/main.tf`.

### 14) What does `enable_dns_hostnames = true` do on the VPC?
Lets instances get DNS names that resolve to their private IPs — needed by many AWS services and by name-based lookups.
See `modules/vpc/main.tf`.

---

## Security Groups

### 15) Are security groups stateful?
Yes. If you allow inbound SSH, the return traffic is automatically allowed — you never add a matching egress rule.
See the comment in `modules/security_group/main.tf`.

### 16) Why reference a security group by ID instead of an IP?
The private EC2 SG allows SSH from `aws_security_group.bastion.id` (not Bastion's IP).
If Bastion is recreated with a new public IP, the rule still works.
See `modules/security_group/main.tf`.

### 17) What is the "least privilege" principle shown here?
Bastion SG allows SSH only from `my_ip` (`203.0.113.45/32`), not `0.0.0.0/0`.
Expose the minimum required surface. See `modules/security_group/main.tf`.

### 18) What does `sensitive = true` do on a variable?
Hides the value from `terraform plan` / `apply` output (your IP and key name won't print).
Used on `my_ip` and `key_name`. See `variables.tf` and `modules/security_group/variables.tf`.

---

## Compute, AMI & Bootstrapping

### 19) What is a data source vs a resource?
A `resource` creates infrastructure; a `data` block reads existing info from the provider.
Here `data "aws_ami" "amazon_linux_2023"` fetches the latest Amazon Linux 2023 AMI ID every run — no hardcoding, never stale.
See `modules/ec2/main.tf`.

### 20) Why avoid hardcoding AMI IDs?
AMI IDs vary by region and are superseded over time. Dynamic lookup keeps code portable and current.
See `modules/ec2/main.tf`.

### 21) What is `user_data` and when does it run?
A script that runs **once** on first boot (cloud-init). Here it installs/starts Nginx and writes the welcome HTML.
It is idempotent-ish but not re-run on reboot — only first launch.
See `modules/ec2/main.tf`.

### 22) What is a Bastion Host and why use one?
A jump server in the public subnet that's the only SSH entry point into the private network.
The Dev Server has no public IP, so you SSH: local → Bastion → Dev Server.
See `modules/ec2/main.tf` and the SSH outputs in `outputs.tf`.

---

## State & Backend

### 23) What is Terraform state and why does it matter?
`terraform.tfstate` maps code resources to real AWS IDs. Without it, Terraform can't plan updates or destroy the right resources.
See the README "Terraform State" section.

### 24) Why use a remote S3 backend?
Local state is lost if your laptop dies. S3 stores state safely with versioning; DynamoDB locks it so two people can't `apply` at once.
See `backend.tf`.

### 25) What is state locking and what problem does it solve?
Locking prevents concurrent operations from corrupting the state file. DynamoDB provides the lock here.
See `backend.tf`.

### 26) What happens if you manually delete a resource in the AWS console?
Next `terraform plan` detects drift (state says it exists, AWS says it doesn't) and will recreate it.
This is why manual changes during a Terraform lifecycle are discouraged.

### 27) What does `terraform force-unlock` do?
Releases a stuck state lock left behind by a crashed `apply`. Use carefully — only if you're sure no one else is running.

---

## Workflow & Validation

### 28) `plan` vs `apply`?
- `plan`: preview only, creates/changes nothing.
- `apply`: executes changes in AWS and writes them to state.

### 29) `validate` vs `fmt`?
- `validate`: checks syntax + semantic validity (catches type errors). Fast, free, no AWS calls.
- `fmt`: reformats code style only.

### 30) Why separate `variables.tf` and `terraform.tfvars`?
`variables.tf` declares *what* inputs exist (types, descriptions, defaults); `terraform.tfvars` provides *your* values.
This lets you have `dev.tfvars`, `staging.tfvars`, `prod.tfvars` over the same code.
See `variables.tf` and `terraform.tfvars`.

### 31) How would you separate dev and prod with this codebase?
Same root code, different `.tfvars` files, separate remote state backends/keys, and ideally separate AWS accounts.

---

## Production Maturity & Extensions

### 32) What's missing from this architecture for production?
- ALB in front of the Dev Server (AUTOSCALE group behind it)
- Multi-AZ NAT for HA (one NAT per AZ) or at least NAT Gateway HA
- Remote state with locking (provided but commented out — `backend.tf`)
- CI/CD with `fmt`, `validate`, `plan` gates before `apply`
- `locals { common_tags }` applied everywhere
- Workspace or environment separation
- Secrets management instead of `sensitive` plain vars

### 33) What are the real-world improvements you'd propose from this repo?
1. Add an ALB module for public-facing load balancing
2. Parameterize `dev_server_count` with `count`
3. Use `terraform workspace` for isolated copies
4. Move `terraform.tfvars` out of git (add to `.gitignore`)
5. Add a CI pipeline that runs `terraform fmt -check` + `validate` + `plan` on PRs

---

## Cost & Safety

### 34) What is the real cost risk in this project?
The **NAT Gateway** (~₹3.75/hr). Everything else is free-tier or near-zero.
Use `enable_nat_gateway = false` while just studying syntax. Always `terraform destroy` afterwards.
See `variables.tf` and the README cost guide.

### 35) Why should `terraform.tfvars` be gitignored?
It contains your real IP and possibly key info. Add `terraform.tfvars`, `*.tfstate`, `.terraform/` to `.gitignore`.
See the note at the bottom of `terraform.tfvars`.