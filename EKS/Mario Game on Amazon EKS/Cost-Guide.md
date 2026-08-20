# 💰 Week 6 Cost-Saving Guide — Super Mario on Kubernetes (Terraform + EKS)

> **Project:** DevOps-Project-12 | **AWS Services:** EKS, EC2 (Nodes), ALB, NAT GW, S3 (Terraform state)

---

## 🚨 Same Risk as Week 5 — EKS is Expensive

This project provisions EKS via Terraform, which adds an extra risk layer: if you run `terraform apply` and forget to `terraform destroy`, the charges accumulate silently.

| Resource | Daily Cost |
|----------|-----------|
| EKS Control Plane | **$2.40/day** |
| EC2 Nodes (t3.small x1) | **$0.50/day** |
| NAT Gateway | **$1.08/day** |
| ALB (LoadBalancer service) | **$0.60/day** |
| **TOTAL** | **~$4.58/day** |

---

## ✅ Cost-Optimized Terraform Config

```hcl
# In your EKS module variables
variable "node_instance_type" {
  default = "t3.small"  # ← Not t3.medium (double the cost!)
}

variable "desired_capacity" {
  default = 1  # ← Minimum nodes
}

variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 1  # ← Prevent autoscaling for labs
}
```

---

## 🗓️ Recommended Lab Day Workflow

```bash
# MORNING: Start your lab
terraform init
terraform plan    # Review what will be created
terraform apply --auto-approve  # Create cluster (~12 minutes)

# DO YOUR LAB WORK (1-2 hours max)
kubectl apply -f deployment.yaml
kubectl get svc
# Test Super Mario in browser

# SAME DAY EVENING: DESTROY EVERYTHING
terraform destroy --auto-approve
# Wait for complete destruction (~10 minutes)

# VERIFY nothing remains
aws eks list-clusters
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

---

## 🔒 Terraform State Safety

```bash
# If terraform gets stuck and can't destroy:
# Manual cleanup order:
# 1. Delete K8s LoadBalancer services first (prevents orphan ELBs)
kubectl delete svc --all

# 2. Then run terraform destroy
terraform destroy --auto-approve

# 3. If Terraform state is corrupted:
terraform state list    # See what state thinks exists
terraform state rm <resource>  # Remove from state if already deleted
```

---

## 📊 Estimated Week 6 Cost

| Scenario | Cost |
|----------|------|
| 2hr lab, terraform destroy same day | **$0.90–1.50** |
| Forgot, left overnight | **$4.58+** |
| Used existing Week 5 cluster | **$0** (already counted) |

> 💡 **Tip:** If your Week 5 EKS cluster still exists (from the same day), reuse it for Week 6 lab to save cluster creation cost!

---

*Part of Hiten Jaypal's 12-Week DevOps Learning Journey*
