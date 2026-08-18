# Comprehensive Deep-Dive Guide: Amazon EKS 2048 Project

This guide explains **every single component, design choice, setting, and error encountered** throughout the setup of your Amazon EKS 2048 project.

---

## 📑 Table of Contents
1. [Part 1 & 2: Networking & Infrastructure (Terraform)](#1-part-1--2-networking--infrastructure-terraform)
2. [Part 3: IAM Roles & Security Permissions](#2-part-3-iam-roles--security-permissions)
3. [Part 4: EKS Cluster Creation & Control Plane](#3-part-4-eks-cluster-creation--control-plane)
4. [Part 5: Managed Node Groups & Worker Nodes](#4-part-5-managed-node-groups--worker-nodes)
5. [Part 6: `kubectl` Authentication & Cluster Access](#5-part-6-kubectl-authentication--cluster-access)
6. [Part 7: Kubernetes Application Deployment (2048 Game)](#6-part-7-kubernetes-application-deployment-2048-game)
7. [Comprehensive Troubleshooting Log](#7-comprehensive-troubleshooting-log)

---

## 1. Part 1 & 2: Networking & Infrastructure (Terraform)

### Why create a custom VPC (`10.20.0.0/16`)?
* **What it is:** A Virtual Private Cloud (VPC) is an isolated virtual network dedicated to your AWS account. `10.20.0.0/16` gives an IP address range from `10.20.0.0` to `10.20.255.255` (65,536 private IP addresses).
* **Why custom instead of default VPC?** The default VPC puts all resources in public subnets with public IP addresses. In production and Kubernetes architecture, worker nodes must run in **private subnets** for security.

### Why 4 Subnets across 2 Availability Zones?
* **Subnet Layout:**
  * `10.20.0.0/24` (Public Subnet 1 - `ap-south-1a`)
  * `10.20.1.0/24` (Public Subnet 2 - `ap-south-1b`)
  * `10.20.10.0/24` (Private Subnet 1 - `ap-south-1a`)
  * `10.20.11.0/24` (Private Subnet 2 - `ap-south-1b`)
* **Why 2 Availability Zones (`ap-south-1a` & `ap-south-1b`)?** EKS requires at least **2 Availability Zones** to ensure High Availability (HA). If one AWS data center fails, the control plane and pods continue operating in the other AZ.
* **Why Public vs. Private?**
  * **Public Subnets:** Contain direct routes to the Internet Gateway. Used for **Load Balancers** (ALB/ELB) and the **NAT Gateway**.
  * **Private Subnets:** Have NO direct route from the internet. Used for **Worker Nodes (EC2 instances)** so hackers cannot directly access your servers.

### Internet Gateway (IGW) vs. NAT Gateway
* **Internet Gateway (IGW):** Allows two-way communication between resources in public subnets and the public internet.
* **NAT Gateway (Network Address Translation):** Placed in a public subnet. Allows EC2 instances in private subnets to initiate **outbound** traffic (e.g. download Docker images, system updates, talk to EKS API) while preventing the outside internet from initiating **inbound** connections directly to those nodes.

### API Security Group (`sg-00762a36aa8871c5b`)
* **What it does:** A stateful firewall attached to the EKS control plane API endpoint on Port 443 (HTTPS).
* **Why created:** Restricts access to the Kubernetes control plane so only authorized IP addresses can send administrative commands.

---

## 2. Part 3: IAM Roles & Security Permissions

AWS identity and Access Management (IAM) separates permissions between **the Control Plane** and **Worker Nodes**.

### A. Cluster IAM Role (`2048-eks-cluster-role`)
* **Service Trust:** `eks.amazonaws.com`
* **Attached Policy:** `AmazonEKSClusterPolicy`
* **Why it's needed:** The EKS Control Plane is managed by AWS inside AWS's account. This role grants the AWS EKS service permission to create Network Interfaces (ENIs), attach security groups, and provision AWS Load Balancers inside **YOUR** AWS account.

### B. Node Group IAM Role (`2048-eks-node-role`)
* **Service Trust:** `ec2.amazonaws.com`
* **Why it's needed:** EC2 worker node instances need permissions to call AWS APIs on your behalf.
* **The 3 Required Policies & What Each Does:**
  1. `AmazonEKSWorkerNodePolicy`: Allows the `kubelet` daemon on the EC2 node to connect, authenticate, and register itself with the EKS Control Plane.
  2. `AmazonEC2ContainerRegistryPullOnly`: Grants read-only access to AWS Elastic Container Registry (ECR) so worker nodes can pull container images.
  3. `AmazonEKS_CNI_Policy`: Grants the **AWS VPC CNI** (Container Network Interface) plugin permission to allocate secondary private IP addresses directly from your VPC subnets to Kubernetes Pods.

> ⚠️ **The Issue We Encountered:**
> Initially, `2048-eks-node-role` was created with **0 policies attached**. Without these policies, the EC2 instance booted up but `kubelet` couldn't attach network interfaces or authenticate with EKS. As a result, the Node Group was stuck in `Creating` status for over 20 minutes!

---

## 3. Part 4: EKS Cluster Creation & Control Plane

### Why Standard/Custom Configuration instead of EKS Auto Mode?
* **EKS Auto Mode:** AWS automatically manages compute (nodes), storage, and ingress.
* **Custom Configuration:** Gives you manual control over subnets, security groups, IAM roles, and managed node groups, which is required for hands-on learning and custom enterprise network architecture.

### Why select ALL 4 Subnets for the Cluster?
* When creating the EKS cluster, you select all 4 subnets (2 public + 2 private). EKS places control plane Cross-Account Elastic Network Interfaces (ENIs) across these subnets to facilitate low-latency communication between the EKS control plane and both public load balancers and private worker nodes.

### Cluster Endpoint Access (Public & Private)
* **Public Endpoint:** Exposes a public DNS URL for `kubectl` management from your local computer.
* **Private Endpoint:** Allows worker nodes inside the VPC to communicate with the EKS API server using internal VPC IPs without routing through the public internet.

> ⚠️ **The Issue We Encountered (NAT Gateway Allowlist Block):**
> Public Access CIDR allowlist was restricted to `106.205.212.246/32` (Home IP). When private worker nodes made DNS calls to the API server, traffic was routed through the **NAT Gateway**, presenting the **NAT Gateway's Elastic IP** as the source. Because the NAT Gateway IP was not in `106.205.212.246/32`, EKS blocked the node connection.
> **Fix:** Set Public Access Allowlist to `0.0.0.0/0`.

---

## 4. Part 5: Managed Node Groups & Worker Nodes

### Why place Node Group ONLY in Private Subnets?
* Worker nodes host your applications and internal cluster services (CoreDNS, kube-proxy). Putting worker nodes in private subnets ensures they do not have public IPv4 addresses, protecting them from direct port scanning or external brute-force attacks.

### Node Configuration Details
* **Instance Type (`t3.medium`):** 2 vCPUs, 4 GiB Memory. Necessary to run Kubernetes system agents (kubelet, containerd, AWS CNI, CoreDNS) + application containers.
* **Scaling Configuration (Desired 1, Min 1, Max 2):** EKS provisions an **AWS EC2 Auto Scaling Group (ASG)**. The ASG launches 1 node initially and can automatically scale up to 2 nodes if CPU/Memory demand increases.

---

## 5. Part 6: `kubectl` Authentication & Cluster Access

### How `kubectl` Authentication Works
1. `aws eks update-kubeconfig` writes cluster connection details (API endpoint, CA certificate, AWS CLI exec credential plugin) to `~/.kube/config`.
2. When you run `kubectl get nodes`, `kubectl` invokes `aws-cli` to generate an STS bearer token using your local AWS credentials.

> ⚠️ **The Issue We Encountered (Root User vs IAM User):**
> The cluster was created in the browser console using the **`root`** account. EKS automatically grants cluster administrator rights *only* to the identity that created the cluster. When `kubectl` executed in CLI under IAM user **`hitenjaypal`**, EKS returned:
> `error: You must be logged in to the server (the server has asked for the client to provide credentials)`
> **Fix:** Created an IAM Access Entry in EKS Console for `arn:aws:iam::252556588942:user/hitenjaypal` and attached `AmazonEKSClusterAdminPolicy`.

---

## 6. Part 7: Kubernetes Application Deployment (2048 Game)

### A. Namespace (`namespace.yaml`)
* **What it does:** Creates a logical boundary named `game-2048` inside Kubernetes to isolate project resources from `default` or `kube-system` namespaces.

### B. Deployment (`2048-deployment.yaml`)
* **What it does:** Specifies 2 replicas of the 2048 game application pod.

> ⚠️ **The Issue We Encountered (Containerd Manifest Schema v1 Error):**
> Pods showed `ErrImagePull` / `ImagePullBackOff`. Running `kubectl describe pod` revealed:
> `media type "application/vnd.docker.distribution.manifest.v1+prettyjws" is no longer supported since containerd v2.1`
> Legacy images (`alexwhen/docker-2048:latest` & `blackicebird/2048:latest`) were built with deprecated Docker Schema v1. Modern Kubernetes 1.36 and `containerd` reject Schema v1.
> **Fix:** Updated image to **`public.ecr.aws/l6e2u8a3/2048:latest`** (official AWS EKS image built with modern OCI Schema v2 manifests).

### C. Service (`2048-service.yaml`)
* **Type:** `LoadBalancer`
* **What it does:** Tells AWS EKS to automatically provision a public **AWS Elastic Load Balancer (ELB)** in your public subnets. The ELB receives external HTTP requests on Port 80 and routes them to Port 80 on the `game-2048` Pods inside your private subnets.

---

## 7. Comprehensive Troubleshooting Log

| Step | Error / Symptom | Root Cause | Exact Solution |
| :--- | :--- | :--- | :--- |
| **Node Group** | Stuck in `Creating` for 20+ min | `2048-eks-node-role` had **0 IAM policies** attached. | Attached `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryPullOnly`. |
| **Networking** | Node could not register | NAT Gateway Elastic IP was blocked by EKS Public Endpoint Allowlist (`106.205.212.246/32`). | Changed Public Access Allowlist in EKS Console to `0.0.0.0/0`. |
| **Security** | Port 443 timeouts | Security Group `sg-00762a36aa8871c5b` didn't allow internal VPC CIDR (`10.20.0.0/16`). | Added HTTPS (Port 443) inbound rule for `10.20.0.0/16`. |
| **kubectl** | `You must be logged in to the server` | Cluster was created by `root`, while CLI used IAM user `hitenjaypal`. | Created Access Entry in EKS for `user/hitenjaypal` with `AmazonEKSClusterAdminPolicy`. |
| **Pods** | `ImagePullBackOff` | Image used deprecated Docker Schema v1 manifest unsupported by `containerd v2.1`. | Updated deployment to `public.ecr.aws/l6e2u8a3/2048:latest` (Schema v2). |
| **kubectl CLI** | `error: you may only specify a single resource type` | `--watch` flag passed multiple resource types (`pods,service`). | Split into separate commands: `kubectl get pods --watch` and `kubectl get svc`. |
