# Terraform Debugging and Real Scenarios

## Scenario 1: `terraform init` fails (provider download issue)
**Symptoms**
- Provider installation error
- Network timeout

**How to debug**
1. Check internet/proxy connectivity
2. Run `terraform init -upgrade`
3. Confirm Terraform version: `terraform version`

---

## Scenario 2: `terraform plan` shows unexpected create/destroy
**Possible causes**
- Manual changes in AWS console (drift)
- Changed variable values
- State mismatch

**How to debug**
1. Run `terraform state list`
2. Inspect a resource: `terraform state show aws_vpc.main`
3. Compare with AWS console
4. Re-run `terraform plan`

---

## Scenario 3: AMI not found in region
**Symptoms**
- Error from `data.aws_ami.amazon_linux_2023`

**How to debug**
1. Verify region in `provider.tf` and variable values
2. Adjust AMI filter if required
3. Test with a known valid AMI ID temporarily

---

## Scenario 4: EC2 not created even after apply
**Cause**
- `create_ec2` is still `false`

**How to debug**
1. Check variable value (`terraform plan` output)
2. Set `create_ec2 = true`
3. Re-run plan and apply

---

## Scenario 5: Route exists but instance has no internet
**Possible causes**
- Missing public IP (expected in this project)
- No NAT for private-only instances
- Security group/network ACL restrictions

**How to debug**
1. Verify subnet route table association
2. Verify IGW attached to VPC
3. Confirm SG egress allows outbound
4. Understand this project keeps EC2 private by default

---

## Scenario 6: Terraform wants to recreate resource after minor edit
**Why this happens**
Some fields are `ForceNew`, meaning update requires replacement.

**How to debug**
1. Read exact plan diff
2. Check provider docs for that resource argument
3. Decide if replacement is acceptable before apply

---

## Scenario 7: Credentials errors (`No valid credential sources`)
**How to debug**
1. Run `aws configure`
2. Check `~/.aws/credentials`
3. Confirm account/region and IAM permissions
4. Test identity: `aws sts get-caller-identity`

---

## Scenario 8: Destroy fails due to dependency
**Example**
- Subnet cannot delete because EC2/network interface still exists

**How to debug**
1. Re-run `terraform destroy`
2. Check remaining dependent resources in AWS
3. Avoid manual console changes during Terraform lifecycle

---

## Recommended Debug Workflow

```bash
terraform fmt
terraform validate
terraform init
terraform plan
terraform apply
terraform state list
terraform output
```

If issue persists:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

---

## Interview Angle: "How would you debug Terraform in production?"

A strong answer:
1. Reproduce in plan output first
2. Check state vs real infra for drift
3. Validate provider/version and variables
4. Use remote state with locking
5. Use CI checks (`fmt`, `validate`, `plan`) before apply
6. Apply reviewed plan only
