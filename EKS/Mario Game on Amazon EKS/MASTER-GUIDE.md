# 🚀 Super Mario on AWS EKS: Complete Project & Interview Master Guide

---

## 📌 Table of Contents
1. [Kubernetes & Terraform Command Reference](#1-kubernetes--terraform-command-reference)
2. [Real-World Technical Challenges & Solutions](#2-real-world-technical-challenges--solutions)
3. [Standard DevOps Interview Questions & Answers](#3-standard-devops-interview-questions--answers)
4. [Advanced Technical Deep-Dive Questions](#4-advanced-technical-deep-dive-questions)
5. [End-to-End Architecture & System How-It-Works](#5-end-to-end-architecture--system-how-it-works)

---

## 1. Kubernetes & Terraform Command Reference

### 🛠️ Infrastructure Provisioning (Terraform)
| Command | Purpose |
| :--- | :--- |
| `terraform init` | Initializes backend S3 state and downloads required AWS provider plugins. |
| `terraform plan` | Previews infrastructure execution plan (16 resources created in this project). |
| `terraform apply -auto-approve` | Provisions VPC, IAM roles, EKS Cluster (`EKS_CLOUD`), Node Group, and CloudWatch logs. |
| `terraform destroy -auto-approve` | Destroys all AWS infrastructure resources to prevent unexpected billing. |

### 🌐 Cluster Context & Connectivity
| Command | Purpose |
| :--- | :--- |
| `aws eks update-kubeconfig --name EKS_CLOUD --region ap-south-1` | Fetches cluster credentials & endpoint from AWS and updates local `~/.kube/config`. |
| `kubectl get nodes -o wide` | Lists all worker nodes, internal/external IPs, OS, kernel versions, and status. |
| `kubectl config current-context` | Shows which EKS cluster context your `kubectl` is currently pointed to. |

### 📦 Application & Manifest Management
| Command | Purpose |
| :--- | :--- |
| `kubectl apply -f deployment.yaml` | Deploys 3 replicas of Super Mario container application. |
| `kubectl apply -f service.yaml` | Exposes Mario pods via an AWS Network Load Balancer (NLB). |
| `kubectl apply -f horizontal-pod-autoscaler.yaml` | Configures HPA to scale pods between 3 and 10 based on CPU/Memory thresholds. |
| `kubectl apply -f network-policy.yaml` | Enforces ingress/egress firewall rules for pod security. |
| `kubectl apply -f service-monitor.yaml` | Configures Prometheus Operator to scrape metrics from Mario service every 30s. |

### 🔍 Inspection, Debugging & Monitoring
| Command | Purpose |
| :--- | :--- |
| `kubectl get pods -w` | Watches pod creation, status changes (`ContainerCreating`, `Running`, `CrashLoopBackOff`) in real-time. |
| `kubectl logs -l app=mario --tail=50` | Streams the last 50 lines of logs from all Mario pods. |
| `kubectl logs <pod-name> --previous` | Fetches container logs from a *previously crashed* pod instance. |
| `kubectl describe pod <pod-name>` | Shows detailed events, image pulls, status codes, and probe failures for a pod. |
| `kubectl get service mario-service` | Retrieves the AWS LoadBalancer `EXTERNAL-IP` DNS URL. |
| `kubectl get hpa mario-hpa` | Checks current CPU/Memory target utilization vs actual usage. |
| `kubectl get deployment,pods,svc,hpa,networkpolicy` | Single-command overview of the entire application stack. |

### 📊 Monitoring Stack (Helm & Grafana)
| Command | Purpose |
| :--- | :--- |
| `helm repo add prometheus-community <url>` | Adds Prometheus Helm repository. |
| `helm install prometheus prometheus-community/kube-prometheus-stack` | Deploys Prometheus, Grafana, Alertmanager, and Operator CRDs. |
| `kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" \| base64 --decode ; echo` | Decodes base64-encoded Grafana `admin` user password. |
| `kubectl port-forward svc/prometheus-grafana 3000:80` | Port-forwards Grafana web interface to `http://localhost:3000`. |

---

## 2. Real-World Technical Challenges & Solutions

### ❌ Challenge 1: `Unable to connect to the server: no such host`
* **Symptom**: `kubectl get nodes` failed with `dial tcp: lookup F3E5FC92...: no such host`.
* **Root Cause**: `~/.kube/config` contained an outdated cluster endpoint URL (`F3E5FC92...`) from a destroyed cluster.
* **Resolution**: Executed `aws eks update-kubeconfig --name EKS_CLOUD --region ap-south-1` to refresh cluster authentication tokens and point to the new cluster endpoint (`BBA68755...`).

### ❌ Challenge 2: Pod `CrashLoopBackOff` (`chown Operation not permitted`)
* **Symptom**: Pods failed with status `CrashLoopBackOff`. `kubectl logs` showed:
  ```text
  [emerg] 1#1: chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
  ```
* **Root Cause**: Nginx master process starts as `root` (UID 0) and attempts to run `chown` on `/var/cache/nginx` for unprivileged worker process (UID 101). In `deployment.yaml`, the container `securityContext` contained:
  ```yaml
  securityContext:
    capabilities:
      drop:
        - ALL
  ```
  Dropping `ALL` capabilities stripped `CAP_CHOWN` from the Linux process, causing the kernel to deny `chown()` system calls.
* **Resolution**: Removed `capabilities.drop: - ALL` from container `securityContext`, restoring necessary `CAP_CHOWN` capabilities for Nginx initialization.

### ❌ Challenge 3: `no matches for kind "ServiceMonitor"` Error
* **Symptom**: Running `kubectl apply -f service-monitor.yaml` failed with `resource mapping not found`.
* **Root Cause**: `ServiceMonitor` is a Custom Resource Definition (CRD) introduced by Prometheus Operator. The native Kubernetes API server does not recognize it until Prometheus Operator is installed.
* **Resolution**: Installed `kube-prometheus-stack` via Helm, which registered the `monitoring.coreos.com/v1` CRDs with the EKS API server.

### ❌ Challenge 4: HPA Showing `<unknown>/70%` Target Utilization
* **Symptom**: `kubectl get hpa mario-hpa` displayed `<unknown>/70%` for CPU utilization.
* **Root Cause**: Kubernetes HPA requires **Metrics Server** to collect pod resource metrics via `metrics.k8s.io` API.
* **Resolution**: Deployed Kubernetes Metrics Server:
  `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`.

---

## 3. Standard DevOps Interview Questions & Answers

### Q1: Describe your Super Mario EKS Project architecture.
> **Answer**: "I built an end-to-end cloud infrastructure on AWS using Terraform to provision an EKS cluster (v1.31) with a managed EC2 node group in custom subnets. On top of EKS, I deployed a highly available 3-replica Super Mario web app exposed via an AWS Network Load Balancer (NLB). I configured Horizontal Pod Autoscaling (HPA) for dynamic scaling, NetworkPolicies for traffic security, and deployed the Prometheus/Grafana stack via Helm for full observability using custom `ServiceMonitor` CRDs."

### Q2: Why did you use an AWS Network Load Balancer (NLB) instead of a Classic Load Balancer?
> **Answer**: "NLBs operate at Layer 4 (Transport layer), handling millions of requests per second with ultra-low latency, cross-zone load balancing, and static IP support. In `service.yaml`, we used annotations (`service.beta.kubernetes.io/aws-load-balancer-type: nlb`) so Kubernetes automatically provisions an AWS NLB integrated with target groups."

### Q3: How do you optimize costs when running EKS in development vs production?
> **Answer**: 
> 1. Use smaller instance types (e.g., `t3.small` for dev, `m5.large` for prod).
> 2. Configure HPA min replicas = 1 or 2 in dev, autoscaling up during traffic spikes.
> 3. Use AWS Spot Instances for worker node groups in non-production environments.
> 4. Destroy idle ephemeral test environments using `terraform destroy`.

---

## 4. Advanced Technical Deep-Dive Questions

### Q1: Explain the difference between `runAsNonRoot: true` vs Linux Capabilities in Kubernetes Security Context.
> **Answer**:
> * `runAsNonRoot: true`: Validates at container start that the container UID is NOT `0` (root). If UID is 0, the pod refuses to start.
> * **Linux Capabilities**: Granular Linux kernel privileges (e.g., `CAP_NET_BIND_SERVICE`, `CAP_CHOWN`, `CAP_SYS_ADMIN`). Even if a process runs as root (UID 0), stripping `CAP_CHOWN` prevents it from modifying file ownership. In our project, Nginx needed root during startup for `chown /var/cache/nginx`, so dropping `ALL` capabilities broke Nginx initialization.

### Q2: How does IRSA (IAM Roles for Service Accounts) work in EKS?
> **Answer**: "IRSA links AWS IAM roles to Kubernetes ServiceAccounts via an **OpenID Connect (OIDC)** provider registered for the EKS cluster. The EKS mutating webhook injects an AWS IAM web identity token into the pod (`AWS_WEB_IDENTITY_TOKEN_FILE`). AWS SDKs read this token and call `sts:AssumeRoleWithWebIdentity`, granting the pod least-privilege access to AWS services without storing static credentials."

### Q3: What is the math formula HPA uses to calculate desired replica count?
> **Answer**:
> $$\text{DesiredReplicas} = \left\lceil \text{CurrentReplicas} \times \left( \frac{\text{CurrentMetricValue}}{\text{TargetMetricValue}} \right) \right\rceil$$
> For example, if target CPU utilization is 70%, current CPU utilization is 140%, and current replicas = 3:
> $$\text{DesiredReplicas} = \left\lceil 3 \times \left( \frac{140}{70} \right) \right\rceil = 6 \text{ Pods}$$

---

## 5. End-to-End Architecture & System How-It-Works

### 🏗️ Architecture Diagram

```mermaid
graph TD
    Client[🌐 User Web Browser] -->|HTTP Port 80| NLB[⚡ AWS Network Load Balancer]
    
    subgraph AWS VPC (ap-south-1)
        subgraph EKS Cluster (EKS_CLOUD v1.31)
            NLB -->|Target Group| Node1[🖥️ Worker Node 1 - t3.small]
            NLB -->|Target Group| Node2[🖥️ Worker Node 2 - t3.small]
            
            subgraph K8s Namespace: default
                Node1 --> Pod1[🐳 Pod: Mario App 1]
                Node1 --> Pod2[🐳 Pod: Mario App 2]
                Node2 --> Pod3[🐳 Pod: Mario App 3]
                
                HPA[📈 HPA: Min 3 / Max 10] -.->|Autoscales| Pod1
                HPA -.->|Autoscales| Pod2
                HPA -.->|Autoscales| Pod3
                
                Prometheus[🔥 Prometheus Server] -->|Scrapes via ServiceMonitor| Pod1
                Prometheus -->|Scrapes via ServiceMonitor| Pod2
                Prometheus -->|Scrapes via ServiceMonitor| Pod3
                
                Grafana[📊 Grafana UI] -->|PromQL Queries| Prometheus
            end
        end
    end
```

### 🔄 End-to-End Lifecycle & Data Flow

1. **Infrastructure Phase**:
   - Terraform communicates with AWS APIs to create VPC subnets, IAM Cluster Roles, CloudWatch Log Groups, EKS Control Plane (`EKS_CLOUD`), and Managed EC2 Node Groups (`Node-cloud`).

2. **Configuration Phase**:
   - `aws eks update-kubeconfig` fetches cluster TLS CA certificates and API endpoint URLs, storing authentication tokens in local `~/.kube/config`.

3. **Application Deployment Phase**:
   - `kubectl apply -f deployment.yaml` submits pod specs to the EKS API Server (kube-apiserver).
   - `kube-scheduler` assigns the 3 Mario pods across healthy EC2 worker nodes.
   - `kubelet` on each node instructs containerd to pull `sevenajay/mario:latest` and start Nginx.

4. **Networking & Routing Phase**:
   - `service.yaml` triggers AWS Load Balancer Controller to create an AWS Network Load Balancer (NLB) and register EC2 node NodePorts as targets.
   - Traffic from client browser hits NLB port 80 -> routes to EC2 NodePort -> routes via Kube-Proxy/AWS VPC CNI -> enters Mario container port 80.

5. **Monitoring & Autoscaling Phase**:
   - **Metrics Server** collects CPU/Memory usage metrics from nodes and pods.
   - **HPA** queries metrics every 15 seconds and scales deployment replicas if CPU > 70%.
   - **Prometheus** uses `ServiceMonitor` definitions to pull metrics every 30s.
   - **Grafana** queries Prometheus using PromQL to visualize real-time cluster health.
