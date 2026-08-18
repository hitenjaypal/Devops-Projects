# Kubernetes (`kubectl`) & AWS EKS Command Cheatsheet

A complete reference guide of AWS CLI and `kubectl` commands for managing, debugging, deploying, and cleaning up EKS cluster resources.

---

## 1. AWS CLI & EKS Authentication Commands

```bash
# Verify currently authenticated AWS IAM user/role
aws sts get-caller-identity

# Connect local kubectl to EKS Cluster (updates ~/.kube/config)
aws eks update-kubeconfig --region ap-south-1 --name 2048-eks-cluster

# List all EKS clusters in the specified region
aws eks list-clusters --region ap-south-1

# Describe detailed configuration and status of an EKS cluster
aws eks describe-cluster --region ap-south-1 --name 2048-eks-cluster

# List node groups in an EKS cluster
aws eks list-nodegroups --region ap-south-1 --cluster-name 2048-eks-cluster
```

---

## 2. Inspecting Nodes (Cluster Infrastructure)

```bash
# List all worker nodes and verify status (Ready / NotReady)
kubectl get nodes

# List worker nodes with IP addresses, OS, kernel, and containerd version
kubectl get nodes -o wide

# View detailed hardware capacity, conditions, taints, and events on a node
kubectl describe node <node-name>
```

---

## 3. Deploying Applications (Applying Manifests)

```bash
# Create the game-2048 Namespace
kubectl apply -f namespace.yaml

# Deploy the 2048 Game Deployment (Pods)
kubectl apply -f 2048-deployment.yaml

# Deploy the LoadBalancer Service (provisions AWS Elastic Load Balancer)
kubectl apply -f 2048-service.yaml

# Apply all YAML files in the current folder
kubectl apply -f .
```

---

## 4. Debugging & Troubleshooting Pods

```bash
# List all Pods in the game-2048 namespace
kubectl get pods -n game-2048

# List Pods with IP addresses and the worker node assigned
kubectl get pods -n game-2048 -o wide

# Live-watch Pod status updates (Ctrl + C to exit)
kubectl get pods -n game-2048 --watch

# CRITICAL DEBUG: View detailed pod events, image pull errors, and status
kubectl describe pod <pod-name> -n game-2048

# View container stdout/stderr logs
kubectl logs <pod-name> -n game-2048

# Follow container logs in real-time
kubectl logs -f <pod-name> -n game-2048

# Open an interactive shell terminal inside a running pod container
kubectl exec -it <pod-name> -n game-2048 -- /bin/sh
```

---

## 5. Services & Load Balancers (Getting the Game URL)

```bash
# Get Service EXTERNAL-IP (AWS LoadBalancer URL)
kubectl get svc -n game-2048

# Describe Service details and inspect target pod IP endpoints
kubectl describe svc game-2048 -n game-2048
```

---

## 6. Updating & Restarting Deployments

```bash
# Imperatively update container image
kubectl set image deployment/game-2048 game-2048=public.ecr.aws/l6e2u8a3/2048:latest -n game-2048

# Restart all Pods in a deployment (Zero-downtime rolling restart)
kubectl rollout restart deployment/game-2048 -n game-2048

# Check rollout progress status
kubectl rollout status deployment/game-2048 -n game-2048
```

---

## 7. Cleanup & Resource Deletion Commands

```bash
# Delete Kubernetes resources in order (Triggers AWS LoadBalancer deletion)
kubectl delete -f 2048-service.yaml
kubectl delete -f 2048-deployment.yaml
kubectl delete -f namespace.yaml

# Delete Node Group via AWS CLI
aws eks delete-nodegroup --region ap-south-1 --cluster-name 2048-eks-cluster --nodegroup-name 2048-node-group-2
aws eks wait nodegroup-deleted --region ap-south-1 --cluster-name 2048-eks-cluster --nodegroup-name 2048-node-group-2

# Delete EKS Cluster via AWS CLI
aws eks delete-cluster --region ap-south-1 --name 2048-eks-cluster
aws eks wait cluster-deleted --region ap-south-1 --name 2048-eks-cluster

# Destroy Terraform VPC Infrastructure
cd terraform
terraform destroy
```
