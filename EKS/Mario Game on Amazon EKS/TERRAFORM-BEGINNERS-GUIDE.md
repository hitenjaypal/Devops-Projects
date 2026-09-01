# 🧱 The Ultimate Beginner's Guide to Terraform (EKS Infrastructure)

Welcome to the comprehensive, line-by-line guide on how Terraform provisions an **Amazon EKS (Elastic Kubernetes Service)** cluster for the Super Mario project!

This guide is written specifically for beginners. We will answer not just **"what"** each line does, but **"why"** we write it this way.

---

## 📍 Table of Contents
1. [What is Terraform and Why Do We Use It?](#1-what-is-terraform-and-why-do-we-use-it)
2. [Core Terraform Concepts](#2-core-terraform-concepts)
3. [Deep-Dive: `provider.tf`](#3-deep-dive-providertf)
4. [Deep-Dive: `backend.tf`](#4-deep-dive-backendtf)
5. [Deep-Dive: `variables.tf` & `terraform.tfvars`](#5-deep-dive-variablestf--terraformtfvars)
6. [Deep-Dive: `main.tf` (The Master Blueprint)](#6-deep-dive-maintf-the-master-blueprint)
   - [EKS Cluster IAM Role](#61-eks-cluster-iam-role)
   - [Default VPC & Security Group](#62-default-vpc--security-group)
   - [EKS Cluster Resource](#63-eks-cluster-resource)
   - [Worker Node Group IAM Role & Policies](#64-worker-node-group-iam-role--policies)
   - [EKS Worker Node Group](#65-eks-worker-node-group)
   - [CloudWatch Log Group](#66-cloudwatch-log-group)
   - [OIDC Identity Provider](#67-oidc-identity-provider)
   - [AWS Load Balancer Controller IAM Role & Customer Policy](#68-aws-load-balancer-controller-iam-role--customer-policy)
7. [Deep-Dive: `outputs.tf`](#7-deep-dive-outputstf)

---

## 1. What is Terraform and Why Do We Use It?

### The Problem (Manual AWS Console Setup)
Imagine creating an EKS cluster by clicking around the AWS Web Console:
1. Click **IAM** -> Create 3 Roles -> Attach 6 Policies manually.
2. Click **VPC** -> Create Security Groups -> Configure Ingress/Egress rules.
3. Click **EKS** -> Create Cluster -> Select Subnets -> Select Version.
4. Click **Node Groups** -> Select Instance Types (`t3.medium`) -> Configure Disk Size -> Set Min/Max nodes.

If you make a single typo or forget a checkbox, the cluster breaks. Worse, if you need to recreate this environment for testing, you have to repeat all 50 clicks from memory!

### The Solution (Infrastructure as Code - IaC)
**Terraform** allows us to write our infrastructure as code files (`.tf`). 
- **Automated**: You run `terraform apply`, and Terraform builds all 15+ AWS resources in minutes.
- **Repeatable**: Anyone on your team can run the code and get the exact same cluster.
- **Version Controlled**: You can track changes to infrastructure in Git just like application code.
- **Destroyable**: You run `terraform destroy`, and everything is cleaned up so you don't get surprise AWS bills!

---

## 2. Core Terraform Concepts

| Concept | Explanation | Real-World Analogy |
| :--- | :--- | :--- |
| **Provider** | The plugin that connects Terraform to a cloud provider (AWS, Azure, GCP, Kubernetes). | A driver for a printer. |
| **Resource** | An infrastructure element you want to create (e.g., EC2, EKS, IAM Role). | Building a wall or door in a house. |
| **Data Source** | Reads information about existing infrastructure that already exists outside Terraform. | Looking up an address in a phonebook. |
| **Variable** | Parameterized input values to make your code reusable. | Ingredients list in a recipe. |
| **State File (`.tfstate`)** | Terraform's memory database mapping your code to actual AWS IDs. | The blueprint registry of a completed house. |

---

## 3. Deep-Dive: `provider.tf`

This file tells Terraform **which plugins** it needs to download and **which cloud account/region** to connect to.

```hcl
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}
```

### Line-by-Line Explanation:
- `required_version = ">= 1.8.0"`: Ensures nobody tries to run this code with an outdated version of Terraform.
- `required_providers`: Tells Terraform to download the official AWS provider (version ~5.70) and Kubernetes provider (version ~2.30) from the HashiCorp registry when you run `terraform init`.
- `provider "aws"`: Configures the AWS plugin.
  - `region = var.aws_region`: Specifies where to build resources (e.g., `ap-south-1` Mumbai).
  - `shared_credentials_files = ["~/.aws/credentials"]`: Reads your AWS credentials (`AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`).
  - `default_tags`: **Why do we use this?** Instead of manually typing tags on every single EC2 instance, IAM role, and Security Group, `default_tags` automatically attaches `Project` and `Environment` tags to *every single resource* created by Terraform!

---

## 4. Deep-Dive: `backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket         = "hiten-mario-eks-tfstate-2026-unique"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

### Why do we use a Remote S3 Backend instead of local files?
- **Local State Problem**: By default, Terraform saves state in a local file called `terraform.tfstate`. If your laptop crashes, your state file is lost, and Terraform loses track of your AWS resources!
- **S3 Bucket**: Stores `terraform.tfstate` safely in the cloud with versioning and encryption (`encrypt = true`).
- **DynamoDB State Locking (`dynamodb_table`)**: Prevents race conditions. If Developer A runs `terraform apply` while Developer B also runs `terraform apply`, DynamoDB "locks" the state so two people cannot modify infrastructure at the exact same second and corrupt state!

---

## 5. Deep-Dive: `variables.tf` & `terraform.tfvars`

### Why separate Variable Definitions (`variables.tf`) from Variable Values (`terraform.tfvars`)?
- `variables.tf` acts as the **schema** (defining what inputs exist, their types, and default fallbacks).
- `terraform.tfvars` acts as the **actual values** for a specific environment (Development vs Production).

#### Example from `variables.tf`:
```hcl
variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.31"
}
```

#### Example from `terraform.tfvars`:
```hcl
eks_version = "1.31"
instance_types = ["t3.medium"]
desired_size = 2
```

---

## 6. Deep-Dive: `main.tf` (The Master Blueprint)

`main.tf` is the main engine of our infrastructure. Let's break it down section by section.

---

### 6.1 EKS Cluster IAM Role

```hcl
# IAM Role for EKS Cluster
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
```

#### Why is this necessary?
- **AWS Security Principle**: AWS services cannot interact with other AWS services unless explicitly granted permission.
- **`assume_role_policy`**: Gives the AWS EKS service (`eks.amazonaws.com`) permission to assume this role.
- **`AmazonEKSClusterPolicy`**: Grants EKS permissions to manage ENIs (Elastic Network Interfaces) and load balancers on your behalf.
- **`AmazonEKSServicePolicy`**: Grants EKS permissions to inspect EC2 resources and auto-scaling groups.

---

### 6.2 Default VPC & Security Group

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

#### Why do we use Data Sources (`data "aws_vpc" "default"`)?
Instead of creating a brand new expensive VPC, `data "aws_vpc" "default"` queries AWS to find your account's existing Default VPC. `data "aws_subnets" "public"` finds all public subnets inside that VPC across multiple Availability Zones (`ap-south-1a`, `ap-south-1b`, `ap-south-1c`).

#### Why do we need `aws_security_group`?
A Security Group acts as a virtual firewall. `egress` with `protocol = "-1"` allows the EKS control plane to send outgoing traffic anywhere (to pull container images, talk to AWS APIs, etc.).

---

### 6.3 EKS Cluster Resource

```hcl
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = data.aws_subnets.public.ids
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }

  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}
```

#### Why do we set these parameters?
- **`version = "1.31"`**: Deploys Kubernetes version 1.31.
- **`role_arn`**: Passes the IAM role we created earlier so AWS EKS can manage control plane infrastructure.
- **`endpoint_public_access = true`**: Allows `kubectl` from your local machine/WSL terminal to connect to the EKS API server over the internet.
- **`depends_on`**: **Crucial!** Ensures Terraform creates the IAM role attachments *before* attempting to create the cluster. If EKS tries to launch without IAM policies attached, cluster creation will fail.

---

### 6.4 Worker Node Group IAM Role & Policies

```hcl
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-cloud"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group_role.name
}
```

#### Why do worker nodes need 4 separate IAM Policies?
1. **`AmazonEKSWorkerNodePolicy`**: Allows EC2 instances to connect to the EKS Cluster control plane.
2. **`AmazonEKS_CNI_Policy`**: Allows the AWS VPC CNI plugin to assign real private IP addresses from your VPC to Kubernetes Pods.
3. **`AmazonEC2ContainerRegistryReadOnly`**: Allows nodes to pull Docker container images from AWS ECR (Elastic Container Registry).
4. **`AmazonSSMManagedInstanceCore`**: Allows AWS Systems Manager (SSM) to connect to worker nodes for debugging without needing open SSH ports.

---

### 6.5 EKS Worker Node Group

```hcl
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = data.aws_subnets.public.ids
  version         = var.eks_version

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 30

  update_config {
    max_unavailable = 1
  }
}
```

#### Key Concepts Explained:
- **`scaling_config`**: 
  - `desired_size = 2`: Starts the cluster with 2 EC2 worker nodes.
  - `min_size = 1`: Allows scaling down to 1 node if idle.
  - `max_size = 4`: Permits scaling up to 4 nodes if traffic spikes.
- **`instance_types = ["t3.medium"]`**: `t3.medium` provides 2 vCPUs and 4GB RAM, perfect for running Kubernetes workloads like Super Mario.
- **`capacity_type = "ON_DEMAND"`**: Guarantees EC2 instance availability without spot instance preemption.

---

### 6.6 CloudWatch Log Group

```hcl
resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
}
```
Stores control plane logs (API server audits, scheduler logs) in AWS CloudWatch. `retention_in_days = 14` automatically deletes old logs after 2 weeks to save cloud costs.

---

### 6.7 OIDC Identity Provider

```hcl
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}
```

#### What is OIDC and why is it revolutionary?
Without OIDC, if a Kubernetes Pod needed to talk to AWS (e.g. create a Load Balancer), you would have to hardcode AWS Access Keys (`AWS_ACCESS_KEY_ID`) inside the container. That is a major security risk!

With **OIDC (OpenID Connect)**, EKS links Kubernetes ServiceAccounts directly to AWS IAM Roles (**IRSA - IAM Roles for Service Accounts**). Kubernetes issues short-lived security tokens to Pods automatically without hardcoded credentials!

---

### 6.8 AWS Load Balancer Controller IAM Role & Customer Policy

```hcl
resource "aws_iam_role" "lb_controller_role" {
  name = "aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = jsonencode({ ... })
}

resource "aws_iam_role_policy_attachment" "lb_controller_policy" {
  policy_arn = aws_iam_policy.lb_controller_policy.arn
  role       = aws_iam_role.lb_controller_role.name
}
```

#### Deep Dive into the Condition Block:
- **`sts:AssumeRoleWithWebIdentity`**: Allows the Pod running in Kubernetes to exchange its ServiceAccount token for AWS IAM permissions.
- **`Condition` -> `StringEquals`**:
  ```hcl
  "${replace(..., "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
  ```
  **Why is this exact string required?** This condition restricts assumption of this IAM role **only** to the specific Kubernetes ServiceAccount named `aws-load-balancer-controller` running in the `kube-system` namespace. No other pod in the cluster can steal or use this IAM role!

---

## 7. Deep-Dive: `outputs.tf`

```hcl
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.eks_cluster.name
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks_cluster.name} --region ${var.aws_region}"
}
```

### What are Outputs for?
After running `terraform apply`, Terraform prints these output values to your terminal. `kubeconfig_command` gives you the exact copy-paste command needed to configure `kubectl` so you can start interacting with your new cluster immediately!

---

## 🚀 Summary Checklist of Commands

1. **`terraform init`**: Initializes directory, downloads AWS & K8s plugins, connects to S3 backend.
2. **`terraform fmt`**: Auto-formats code to match standard HCL style.
3. **`terraform validate`**: Checks code syntax and internal logic.
4. **`terraform plan`**: Simulates deployment and displays a dry run of what will be created (+), modified (~), or destroyed (-).
5. **`terraform apply`**: Executes the blueprint and creates resources in AWS.
6. **`terraform destroy`**: Cleans up and deletes all AWS resources to avoid charges.
