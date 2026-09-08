# 🚀 Week 07: Helm on EKS — Kubernetes Package Manager & Microservices Deployment

> **12-Week DevOps Learning Journey — Week 7 Project (Project #15)**
> **Difficulty:** Intermediate → Advanced | **Cloud Provider:** AWS | **Estimated Time:** 2.5–3.5 hours | **Cost:** ~$1.00 – $2.00 per lab session

A production-grade Kubernetes project demonstrating **Helm Package Management**, **Multi-Microservice Architecture**, **Persistent Volumes (EBS CSI Driver)**, and **AWS Ingress ALB Integration** on Amazon EKS. In this project, you will deploy a complete 10+ microservice e-commerce application (RobotShop) using a single, unified Helm chart, configure IAM OIDC and EBS storage controllers, and manage chart releases, upgrades, and rollbacks.

---

## 📌 Project Overview & What You Will Build

| Layer | Technology Used | Description / Purpose |
|---|---|---|
| **Package Management** | Helm v3 | Packaging, templating, parameterizing, and releasing multi-microservice K8s applications |
| **Cluster Compute** | Amazon EKS (v1.30+) | Managed Kubernetes control plane with multi-AZ worker node groups |
| **Storage Driver** | AWS EBS CSI Driver | Dynamic provisioning of AWS EBS volumes for stateful databases (MySQL, MongoDB) |
| **Ingress Controller** | AWS Load Balancer Controller | Automatic provisioning of AWS Application Load Balancers (ALBs) via Ingress |
| **Microservices App** | RobotShop (10+ Services) | Polyglot microservices (Node.js, Java, Python, PHP, Go, MongoDB, MySQL, Redis, RabbitMQ) |
| **Security & Identity** | IAM OIDC & IRSA | IAM Roles for Service Accounts securing EBS CSI driver and ALB controller |

---

## 🌐 High-Level System Architecture

```
                                  INTERNET
                                     │
                                     ▼
                      ┌─────────────────────────────┐
                      │ AWS Application Load        │
                      │ Balancer (ALB)              │
                      └──────────────┬──────────────┘
                                     │ HTTP Traffic (Port 80)
                                     ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       AMAZON EKS VPC                                           │
│                                                                                                │
│   ┌────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │   Ingress Controller (AWS Load Balancer Controller)                                    │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │ Nginx Web Ingress                                  │
│                                           ▼                                                    │
│   ┌────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │   ROBOT-SHOP HELM RELEASE (Namespace: robot-shop)                                      │   │
│   │                                                                                        │   │
│   │   ┌────────────────┐      ┌────────────────┐      ┌────────────────┐                   │   │
│   │   │ Web (Nginx UI) │ ───► │ Catalogue      │ ───► │ MongoDB        │ ───► [ EBS PVC ]  │   │
│   │   └────────────────┘      │ (Node.js API)  │      │ (Document DB)  │      (Persistent)  │   │
│   │           │               └────────────────┘      └────────────────┘                   │   │
│   │           ▼                       │                                                    │   │
│   │   ┌────────────────┐              ▼                       ┌────────────────┐           │   │
│   │   │ Cart (Node.js) │ ───► ┌────────────────┐              │ MySQL          │           │   │
│   │   └───────┬────────┘      │ User (Node.js) │ ───────────► │ (Auth DB)      │ ──► [EBS] │   │
│   │           │               └────────────────┘              └────────────────┘           │   │
│   │           ▼                       │                                                    │   │
│   │   ┌────────────────┐              ▼                       ┌────────────────┐           │   │
│   │   │ Redis Cache    │      ┌────────────────┐              │ RabbitMQ       │           │   │
│   │   └────────────────┘      │ Shipping(Java) │ ───────────► │ (Queue)        │           │   │
│   │                           └────────────────┘              └────────────────┘           │   │
│   └────────────────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites & Required Tooling

Ensure the following CLI tools are installed on your workstation:

1. **AWS CLI v2**: Installed (`aws --version`) and configured (`aws configure`).
2. **`eksctl`**: Version 0.170+ (`eksctl version`).
3. **`kubectl`**: Installed (`kubectl version --client`).
4. **Helm v3**: Version 3.10+ installed (`helm version`).
5. **Git**: Installed (`git --version`).

---

## 📁 Repository Structure

```
├── README.md                              # Main Setup & Workflow Guide
├── ARCHITECTURE.md                        # Architecture Deep Dive & Microservices Breakdown
├── INTERVIEW-QUESTIONS.md                 # 30+ Interview Q&A on Helm, EBS CSI & EKS
├── WHAT-YOU-WILL-LEARN.md                 # Helm Concepts, Command Cheat Sheet & Best Practices
└── Cost-Guide.md                          # AWS Pricing Breakdown & Cleanup Guide
```

---

## 🚀 Step-by-Step Hands-On Implementation Workflow

### Step 1: Create Amazon EKS Cluster
Create a multi-AZ EKS cluster with 2 worker nodes:

```bash
eksctl create cluster \
  --name robotshop-cluster \
  --region us-east-1 \
  --nodegroup-name robotshop-nodes \
  --node-type t3.medium \
  --nodes 2 --nodes-min 1 --nodes-max 3 \
  --managed
```

### Step 2: Configure IAM OIDC Provider
Enable IAM Roles for Service Accounts (IRSA):

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster robotshop-cluster \
  --region us-east-1 \
  --approve
```

### Step 3: Install AWS Load Balancer Controller via Helm
1. Download IAM Policy and create IAM role:
   ```bash
   curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
   aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

   eksctl create iamserviceaccount \
     --cluster=robotshop-cluster --namespace=kube-system \
     --name=aws-load-balancer-controller \
     --role-name AmazonEKSLoadBalancerControllerRole \
     --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy --approve
   ```
2. Install Controller with Helm:
   ```bash
   helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=robotshop-cluster \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller
   ```

### Step 4: Install AWS EBS CSI Driver for Persistent Storage
Stateful databases (MongoDB, MySQL) require persistent storage backed by AWS EBS volumes:

```bash
# 1. Create IAM Role for EBS CSI Controller
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa --namespace kube-system \
  --cluster robotshop-cluster --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve

# 2. Add EBS CSI Driver EKS Add-on
eksctl create addon --name aws-ebs-csi-driver --cluster robotshop-cluster \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole --force
```

### Step 5: Deploy RobotShop Microservices via Helm
1. Clone the Helm deployment repository:
   ```bash
   git clone https://github.com/uniquesreedhar/RobotShop-Project.git
   cd RobotShop-Project/EKS/helm
   ```
2. Create dedicated namespace and install the Helm chart:
   ```bash
   kubectl create namespace robot-shop
   helm install robot-shop --namespace robot-shop .
   ```
   *This deploys all 10+ microservices, ConfigMaps, Secrets, PVCs, and Services in a single command!*

### Step 6: Create Ingress & Access E-Commerce Application
1. Apply the Ingress manifest:
   ```bash
   kubectl apply -f ingress.yaml -n robot-shop
   ```
2. Get the ALB DNS URL:
   ```bash
   kubectl get ingress -n robot-shop
   ```
3. Copy the `ADDRESS` host and paste it into your browser to browse products, add items to cart, and test checkout.

---

## ✅ Verification & Validation Steps

1. **Verify All Helm Releases**:
   ```bash
   helm list -n robot-shop
   helm status robot-shop -n robot-shop
   ```
2. **Verify Pod & PVC Status**:
   ```bash
   kubectl get pods -n robot-shop
   kubectl get pvc -n robot-shop
   ```

---

## 🧹 Cost Safeguard & Cleanup Instructions

Always delete resources when finished to avoid lingering AWS charges:

```bash
# Delete Ingress
kubectl delete ingress --all -n robot-shop

# Uninstall Helm Release
helm uninstall robot-shop -n robot-shop

# Delete Cluster via eksctl
eksctl delete cluster --name robotshop-cluster --region us-east-1
```

---

## 📚 Related Documentation Files

- [ARCHITECTURE.md](ARCHITECTURE.md) — Microservices architecture & persistent storage flow.
- [INTERVIEW-QUESTIONS.md](INTERVIEW-QUESTIONS.md) — 30+ scenario-based interview Q&A.
- [WHAT-YOU-WILL-LEARN.md](WHAT-YOU-WILL-LEARN.md) — Helm CLI cheat sheet & best practices.
- [Cost-Guide.md](Cost-Guide.md) — AWS pricing & budget control tips.
