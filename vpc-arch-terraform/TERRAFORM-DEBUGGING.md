# Terraform Debugging and Real Scenarios (Week 2 — Modules)

> Scenarios ordered the way you'll actually hit them: init → plan → apply → runtime → destroy.
> Each one has a *symptom*, *cause*, and *fix* tuned to this modular VPC stack.

---

## Scenario 1: `terraform init` fails — provider download error

**Symptoms**
- `Failed to install provider` / network timeout
- `Error: Failed to query available provider packages`

**How to debug**
1. Check internet/proxy connectivity.
2. Confirm version: `terraform version` (must be `>= 1.5.0` per `provider.tf`).
3. Retry: `terraform init -upgrade`.
4. If behind a proxy, set `HTTP_PROXY` / `HTTPS_PROXY` env vars.

---

## Scenario 2: Module not found after adding a new module

**Symptoms**
- `Error: Module not installed` or `The module address could not be resolved`

**Cause**
You added/changed a `source = "./modules/..."` path but didn't re-init.
Terraform only installs modules during `terraform init`.

**How to debug**
1. Confirm the folder exists under `modules/`.
2. Run `terraform init` (or `terraform init -upgrade`).
3. Verify it appears under `.terraform/modules/`.

---

## Scenario 3: `terraform plan` shows a resource being recreated after a tiny edit

**Cause**
Some arguments are `ForceNew` — changing them forces replacement (e.g., VPC CIDR, subnet CIDR).

**How to debug**
1. Read the exact `plan` diff — the `+/-` forces-new marker is shown.
2. Check the AWS provider docs for that argument.
3. Decide: revert the edit, or accept the replacement.
4. For this project, changing `vpc_cidr` or subnet CIDRs will rebuild the whole stack — change `terraform.tfvars` deliberately.

---

## Scenario 4: AMI data source returns no AMI

**Symptoms**
- `data.aws_ami.amazon_linux_2023: Your query returned no results`
- `InvalidAMIID.NotFound`

**How to debug**
1. Verify region in `terraform.tfvars` / `provider.tf`.
2. Confirm the filter matches al2023 in that region.
3. Temporarily test with a known-good AMI ID to isolate filter vs region issue.
4. Remember AMI IDs differ by region — never hardcode across regions.
See `modules/ec2/main.tf`.

---

## Scenario 5: `Error: No valid credential sources found`

**Symptoms**
- Provider can't authenticate to AWS.

**How to debug**
1. Run `aws configure` (set access key, secret, region `ap-south-1`).
2. Inspect `~/.aws/credentials` and `~/.aws/config`.
3. Confirm IAM permissions for VPC/EC2/SG/EIP/NAT/DynamoDB/S3.
4. Test identity: `aws sts get-caller-identity`.

---

## Scenario 6: `Error acquiring the state lock`

**Symptoms**
- `Error acquiring the state lock. Lock Info: ...`

**Cause**
A previous `apply` crashed or another teammate is running Terraform.

**How to debug**
1. Make sure no one else is running `apply` right now.
2. If a run genuinely crashed: `terraform force-unlock <LOCK-ID>`.
3. Re-run `terraform plan` to confirm lock released.
4. With the S3+DynamoDB backend this is largely automatic — see `backend.tf`.

---

## Scenario 7: `InvalidKeyPair.NotFound`

**Symptoms**
- EC2 creation fails with key pair not found.

**Cause**
The `key_name` in `terraform.tfvars` doesn't exist in `ap-south-1` (or wrong region).

**How to debug**
1. EC2 Console → Key Pairs in `ap-south-1`.
2. Create the key pair with the exact name used in `terraform.tfvars`.
3. Keep the `.pem` safe — you can't re-download it.
4. Re-run `terraform apply`.
See `variables.tf` (`key_name`).

---

## Scenario 8: SSH to Bastion times out

**Symptoms**
- `ssh: connect to host ... port 22: Connection timed out`

**Possible cause**
Your public IP changed since the last `apply`, so the Bastion SG no longer allows your IP.

**How to debug**
1. Get your current IP: `curl https://checkip.amazonaws.com`.
2. Update `my_ip` in `terraform.tfvars` to `<ip>/32`.
3. `terraform apply` (it will update the SG ingress rule).
4. Confirm the Bastion SG inbound rule in the console matches your new IP.
See `modules/security_group/main.tf`.

---

## Scenario 9: Bastion connects, but SSH to private Dev Server fails

**Symptoms**
- From Bastion, `ssh ... <dev-private-ip>` hangs or is refused.

**Possible causes**
- Private EC2 SG doesn't allow SSH from the Bastion SG.
- You're using the wrong key file on Bastion.
- Dev Server is still booting.

**How to debug**
1. Confirm `private-ec2-sg` ingress allows port 22 from `bastion-sg` (it does by design — `modules/security_group/main.tf`).
2. Make sure the `.pem` key on Bastion matches `var.key_name`.
3. Check instance state: `aws ec2 describe-instances --region ap-south-1 ...`.
4. Wait 1–2 minutes after `apply` for the instance to be ready.
5. From Bastion, use the exact command from the `step2_ssh_to_dev_server` output.

---

## Scenario 10: Nginx not responding on Dev Server

**Symptoms**
- `curl http://localhost` returns nothing or 502/ refused.

**Cause**
`user_data` is still running (takes ~1–2 min after instance ready) or it failed.

**How to debug**
1. Wait and retry.
2. SSH in and check logs: `sudo tail -n 100 /var/log/cloud-init-output.log`.
3. `sudo systemctl status nginx` and `sudo systemctl restart nginx`.
4. Verify the page: `curl http://localhost`.
5. If `user_data` errored, `set -e` will have stopped it early — fix the script in `modules/ec2/main.tf` and re-apply.

---

## Scenario 11: Private Dev Server has no internet (NAT path)

**Symptoms**
- `curl https://checkip.amazonaws.com` from the Dev Server fails.
- `dnf update` can't reach mirrors.

**Possible causes**
- `enable_nat_gateway = false` (study mode) — no egress.
- NAT Gateway not yet "Available" (takes a few minutes).
- Private route table missing the `0.0.0.0/0 → NAT` route.

**How to debug**
1. Check `enable_nat_gateway` in `terraform.tfvars`.
2. In the console, confirm NAT Gateway status = `Available`.
3. Confirm private route table has the NAT route.
4. Confirm private EC2 egress SG allows all outbound (it does — `modules/security_group/main.tf`).
5. When NAT works, `curl https://checkip.amazonaws.com` should return the **NAT EIP**, not your IP.

---

## Scenario 12: `destroy` fails because of dependencies

**Example**
- NAT Gateway / EIP can't delete while EC2 interfaces still reference it.
- Subnet won't delete while instances exist.

**How to debug**
1. Re-run `terraform destroy` — transient AWS delays often resolve.
2. Check remaining resources: `aws ec2 describe-instances`, NAT GWs, EIPs in the console.
3. NAT Gateways take a few minutes to delete — wait, then retry.
4. Avoid manual console deletes mid-lifecycle; if you did, `terraform refresh` then `destroy`.

---

## Scenario 13: Backend initialization required / config changed

**Symptoms**
- `Error: Backend initialization required, please run "terraform init"`
- You uncommented the `backend "s3"` block in `backend.tf`.

**How to debug**
1. Ensure the S3 bucket + DynamoDB table exist (commands in `backend.tf`).
2. Run `terraform init -reconfigure` to switch backends cleanly.
3. If migrating from local state, Terraform will offer to copy existing state — say **yes**.
4. Confirm: `terraform state list` should still show all resources.

---

## Scenario 14: State drift after manual console changes

**Symptoms**
- `plan` wants to recreate/repair resources you didn't touch in code.

**Cause**
Someone changed something in the AWS Console (drift).

**How to debug**
1. `terraform state list` → `terraform state show <addr>` to compare with console.
2. Either revert the console change or accept the code as source of truth and `apply`.
3. Going forward, ban manual changes; enforce via CI (`validate` + `plan`) and IAM boundaries.

---

## Recommended Debug Workflow

```bash
terraform fmt
terraform validate
terraform init
terraform plan
terraform apply
terraform state list
terraform state show aws_vpc.main
terraform output
```

If an issue persists, capture a plan file for inspection:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

For verbose provider logging (study mode only — sensitive data may print):

```bash
TF_LOG=DEBUG terraform plan 2>&1 | tee plan.log
```

---

## Interview Angle: "How would you debug Terraform in production?"

A strong, structured answer:

1. **Reproduce in `plan` output first** — never debug by applying.
2. **Check state vs real infra** for drift (`state show` vs console).
3. **Validate provider/version and variables** (`terraform validate`, `terraform version`).
4. **Use remote state with locking** (S3 + DynamoDB — see `backend.tf`).
5. **Gate changes in CI**: `fmt -check`, `validate`, `plan` before any `apply`.
6. **Apply reviewed plans only** (`plan -out=tfplan`, then `apply tfplan`).
7. **Rotate secrets safely** — don't leak via `TF_LOG`; use `sensitive = true` and a secrets manager.

---

## Quick Command Cheat-Sheet

| Command                              | Purpose                                  |
| ------------------------------------ | ---------------------------------------- |
| `terraform init`                     | Install providers + modules + backend    |
| `terraform init -reconfigure`        | Switch backend config cleanly            |
| `terraform validate`                 | Syntax + semantic checks, no AWS        |
| `terraform fmt` / `fmt -check`       | Format / enforce format in CI            |
| `terraform plan`                     | Preview changes                           |
| `terraform plan -out=tfplan`         | Save a plan to apply later               |
| `terraform apply`                    | Execute changes                          |
| `terraform apply tfplan`             | Apply a saved plan (no re-prompt)        |
| `terraform output`                   | Print all outputs                        |
| `terraform output bastion_public_ip` | Print one output                         |
| `terraform state list`               | List tracked resources                   |
| `terraform state show <addr>`        | Inspect one resource from state          |
| `terraform force-unlock <ID>`        | Release a stuck state lock               |
| `terraform destroy`                  | Tear down everything tracked by state    |