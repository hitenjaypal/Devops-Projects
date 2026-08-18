# 💰 Week 5 Cost-Saving Guide — Kubernetes End-to-End on EKS

> **Project:** DevOps-Project-08 | **AWS Services:** EKS, EC2 (Node Group), VPC, ELB

---

## 🚨 EKS is THE MOST Expensive Week — Read Carefully!

| Resource                           | Cost                       | Notes                       |
| ---------------------------------- | -------------------------- | --------------------------- |
| **EKS Control Plane**              | **$0.10/hr = $2.40/day**   | Charged even with no nodes! |
| **EC2 Node (t3.medium)**           | $0.0416/hr = **$1.00/day** | Default node type           |
| **EC2 Node (t3.small)**            | $0.0208/hr = **$0.50/day** | Better for labs             |
| **ELB (LoadBalancer Service)**     | $0.025/hr = **$0.60/day**  | Auto-created by K8s         |
| **NAT Gateway** (EKS auto-creates) | $0.045/hr = **$1.08/day**  | Created by eksctl           |
| **EBS volumes per node**           | $0.10/GB/month             | Minimal                     |

### Daily Cost If Left Running

```
EKS Control Plane: $2.40
Node (t3.medium):  $1.00
ELB:               $0.60
NAT Gateway:       $1.08
━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL/DAY:        ~$5.08/day
TOTAL/WEEK:       ~$35.56
```

> 🚨 **NEVER leave EKS running overnight! Delete the cluster the same day.**

---

## ✅ Minimum-Cost EKS Configuration

```bash
# Use smallest possible nodes
eksctl create cluster \
  --name learning-cluster \
  --region us-east-1 \
  --node-type t3.small \      # ← Use small, not medium
  --nodes 1 \                  # ← Only 1 node minimum
  --nodes-min 1 \
  --nodes-max 1 \              # ← No autoscaling for lab
  --managed
```

---

## 🌍 Use AWS CloudShell (FREE!)

Instead of running `kubectl` from EC2, use AWS CloudShell:

- 100% FREE
- `kubectl` + `eksctl` + `aws` CLI pre-installed
- No EC2 required for management

```bash
# In AWS CloudShell (no cost):
aws eks update-kubeconfig --region us-east-1 --name learning-cluster
kubectl get nodes
kubectl apply -f 2048-pod.yaml
```

---

## ⏱️ Fastest Lab Workflow (Minimize Cost)

```bash
# 1. Create cluster (10-12 minutes — $0.017 to create)
eksctl create cluster --name lab --region us-east-1 \
  --node-type t3.small --nodes 1 --managed

# 2. Do your lab work (target: complete in 1-2 hours)
kubectl apply -f 2048-pod.yaml
kubectl apply -f mygame-svc.yaml
kubectl get svc  # Get LoadBalancer URL
# Test the game in browser

# 3. DELETE IMMEDIATELY after testing
eksctl delete cluster --name lab --region us-east-1
# This takes 5-10 minutes — wait for it to complete!
```

---

## 🆓 Free Alternatives to Practice Kubernetes

Study Kubernetes fundamentals WITHOUT AWS cost:

| Platform             | Cost | What You Get           |
| -------------------- | ---- | ---------------------- |
| **KillerCoda**       | FREE | Browser-based K8s labs |
| **Play with K8s**    | FREE | 4-hour sessions        |
| **Minikube** (local) | FREE | Local K8s cluster      |
| **Kind** (local)     | FREE | K8s in Docker          |
| **k3s** (local)      | FREE | Lightweight K8s        |

```bash
# Install minikube locally (Windows)
winget install Kubernetes.minikube

# Start local cluster (no AWS charges)
minikube start

# Practice same kubectl commands
kubectl apply -f 2048-pod.yaml
kubectl get pods
```

---

## 🗓️ Recommended Schedule to Minimize Cost

```
Monday:    Study K8s concepts on KillerCoda (FREE)
Tuesday:   Study K8s concepts on KillerCoda (FREE)
Wednesday: Deploy real EKS cluster (2 hours max, DELETE same day)
Thursday:  Practice with Minikube locally (FREE)
Friday:    Review + document what you learned
```

---

## ✅ CRITICAL: Cluster Deletion Verification

```bash
# After eksctl delete cluster:
# ✅ Verify cluster is gone
aws eks list-clusters

# ✅ Verify no orphan node EC2s
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key=='aws:eks:cluster-name'].Value|[0]]" \
  --output table

# ✅ Verify NAT Gateway is deleted
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query "NatGateways[*].[NatGatewayId,State]" \
  --output table

# ✅ Verify Load Balancers are deleted
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].[LoadBalancerName,State.Code]" \
  --output table
```

---

## 📊 Estimated Week 5 Cost

| Scenario                                         | Cost           |
| ------------------------------------------------ | -------------- |
| 1 EKS cluster, 1 node, 2hr lab, deleted same day | **$1.00–1.50** |
| 1 EKS cluster, forgot to delete, overnight       | **$5.00+**     |
| Left running for 3 days                          | **$15.00+**    |
| Used Minikube locally (supplement)               | **$0.00**      |

> 💡 **Target:** Week 5 real AWS cost under **$2.00** by deleting cluster after each session.

---

_Part of Hiten Jaypal's 12-Week DevOps Learning Journey_
