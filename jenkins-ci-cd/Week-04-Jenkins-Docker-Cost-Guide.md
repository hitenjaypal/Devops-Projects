# 💰 Week 4 Cost-Saving Guide — Jenkins + Docker CI/CD on AWS

> **Project:** DevOps-Project-05 | **AWS Services:** EC2 x2 (Jenkins + Docker Host)

---

## 🚨 Cost Profile: Relatively Cheap Week

This project uses only **2 EC2 instances** — the most cost-effective compute option.

| Resource | Cost | Notes |
|----------|------|-------|
| **Jenkins Server (t2.micro)** | Free Tier (750hrs/month first year) | **FREE** |
| **Docker Host (t2.micro)** | Free Tier (750hrs/month first year) | **FREE** |
| **Security Groups** | FREE | - |
| **Key Pairs** | FREE | - |
| **EBS Volumes (8GB)** | 30GB free tier/month | **FREE** |

> ⚠️ **Free Tier only gives you 750 EC2 hours/month across ALL t2.micro instances.** 2 machines x 24hrs = 48hrs/day. You'll exhaust 750hrs in ~15 days if left running 24/7.

---

## 💡 Cost-Optimized Setup

### Use ONE EC2 instead of TWO
The project uses 2 separate EC2s (Jenkins + Docker Host) to teach SSH concepts. For saving money, run both on one machine:

```bash
# On a single t2.micro:
# Run Jenkins on port 8080
# Run Docker on the same machine
# Skip the "Publish Over SSH" plugin complexity
```

### Instance Lifecycle — Stop, Don't Terminate
```bash
# STOP the instance when not using (not Terminate)
# Stopped instances: No compute charge, only EBS storage charge (minimal)
# EBS 8GB = $0.10/month = $0.003/day — negligible!

aws ec2 stop-instances --instance-ids i-xxxx
# Resume later:
aws ec2 start-instances --instance-ids i-xxxx
```

> 💡 **Stop vs Terminate:** Stop preserves your Jenkins config. Terminate deletes everything. Always **STOP** for Week 4!

---

## 🛠️ Save Bootstrap Time (Stop Instead of Terminate)

Setting up Jenkins + Maven + Docker takes 1-2 hours. Save your work:

```bash
# After finishing for the day — STOP (not terminate!)
aws ec2 stop-instances --instance-ids i-jenkins-id i-docker-id

# Next day — Start and continue
aws ec2 start-instances --instance-ids i-jenkins-id i-docker-id
```

---

## 🔔 Free Tier Monitoring

```bash
# Check your Free Tier usage
# AWS Console → Billing → Free Tier
# Or:
aws ce get-right-sizing-recommendation --service "EC2"
```

---

## 📊 Estimated Week 4 Cost

| Scenario | Estimated Cost |
|----------|---------------|
| 2x t2.micro, 2hrs/day active, stopped otherwise | **$0.00** (Free Tier) |
| 2x t2.micro, left running 24/7 for 7 days | **~$3.50** (past Free Tier) |
| Used t3.medium instead of t2.micro | **$0.83/day** |

> 💡 **Target:** Week 4 should cost **$0** if you use Free Tier and stop instances when done.

---

## ✅ End-of-Session Checklist

```bash
# 1. Stop (not terminate) both instances
aws ec2 stop-instances --instance-ids <jenkins-id> <docker-id>

# 2. Confirm stopped
aws ec2 describe-instances \
  --instance-ids <jenkins-id> <docker-id> \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table
```

---

*Part of Hiten Jaypal's 12-Week DevOps Learning Journey*
