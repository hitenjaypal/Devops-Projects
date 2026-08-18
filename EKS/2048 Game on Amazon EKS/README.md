# Hands-on Project: Deploy the 2048 Game on Amazon EKS

This lab uses Terraform only for **Part 1 (VPC)** and **Part 2 (security group)**. You will create the IAM roles, EKS cluster, managed node group, and Kubernetes application manually to understand them properly.

Read [ARCHITECTURE.md](ARCHITECTURE.md) before starting for the complete request flow and resource ownership. Use [KUBERNETES-YAML-GUIDE.md](KUBERNETES-YAML-GUIDE.md) to understand each Kubernetes YAML field, then use [INTERVIEW-QUESTIONS.md](INTERVIEW-QUESTIONS.md) after each stage to test your understanding.

## Architecture

```text
Terraform: VPC, 2 public subnets, 2 private subnets, NAT gateway, API security group
                                      |
Manual AWS Console: IAM roles, EKS cluster, managed node group
                                      |
Manual kubectl: Namespace, Deployment, Service (LoadBalancer)
                                      |
Browser: 2048 game
```

## Before you start

Install AWS CLI v2, Terraform 1.6+, and `kubectl`. Your AWS identity needs permissions for VPC, EC2, EKS, IAM, and Elastic Load Balancing.

```bash
aws sts get-caller-identity
terraform -version
kubectl version --client
```

> Cost warning: an EKS cluster, NAT gateway, EC2 node, and LoadBalancer all incur AWS charges. Keep this README open and complete the cleanup section when finished.

## Part 1 and 2: Create the VPC and API security group with Terraform

Terraform creates these resources only:

- VPC: `10.20.0.0/16`
- Two public subnets, for the public load balancer
- Two private subnets, for EKS worker nodes
- Internet gateway, route tables, one NAT gateway, and an Elastic IP
- Required EKS subnet tags
- An additional EKS API security group allowing TCP 443 only from your public IP

It does **not** create IAM roles, EKS, nodes, Pods, or the load balancer.

### 1. Configure your variables

Open an Ubuntu terminal in this project and run:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
curl https://checkip.amazonaws.com
```

Edit `terraform.tfvars` and replace the example `admin_cidr` with the result plus `/32`:

```hcl
aws_region   = "ap-south-1"
project_name = "2048-eks"
cluster_name = "2048-eks-cluster"
admin_cidr   = "YOUR.PUBLIC.IP.ADDRESS/32"
```

For example, if the command returns `49.36.10.20`, set `admin_cidr = "49.36.10.20/32"`. `/32` means exactly your one IP address; do not use `0.0.0.0/0`.

### 2. Review before creating anything

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Read the plan. You should see VPC/network/security-group resources and no EKS cluster resource. Only when you understand it, create them:

```bash
terraform apply
```

Type `yes` only after reviewing the final plan. Save the output values; you can also see them anytime with:

```bash
terraform output
```

### What each resource teaches you

- **Public subnet**: has a route to the Internet Gateway. The future public LoadBalancer goes here.
- **Private subnet**: no direct inbound internet route. Your worker nodes use these subnets.
- **NAT gateway**: gives private nodes outbound internet access to pull images without exposing them publicly.
- **Subnet tags**: allow EKS and the load balancer integration to identify appropriate subnets.
- **Security group**: stateful firewall. This one permits Kubernetes API TCP 443 only from `admin_cidr`. There is no need to open ports 22, 80, or 8080 to worker nodes.

## Part 3: Create EKS IAM roles manually

### Cluster role

1. Go to **IAM → Roles → Create role**.
2. Select **AWS service → EKS → EKS - Cluster**.
3. Name it `2048-eks-cluster-role`.
4. Confirm the policy `AmazonEKSClusterPolicy` is attached.

### Node group role

1. Create another role for **AWS service → EC2**.
2. Name it `2048-eks-node-role`.
3. Attach these policies:

   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2ContainerRegistryPullOnly`
   - `AmazonEKS_CNI_Policy`

## Part 4: Create EKS manually

1. Open **EKS → Clusters → Create cluster → Custom configuration**.
2. Use the same Region configured in `terraform.tfvars`.
3. Set the cluster name to `2048-eks-cluster` (or the `cluster_name` value from your variables).
4. Choose the latest standard-supported Kubernetes version shown by the console.
5. Select `2048-eks-cluster-role` as the cluster service role.
6. Select the VPC created by Terraform. Select all four Terraform-created subnets for the cluster.
7. Under **Cluster endpoint access**, select public and private. Restrict public access to the same IP CIDR used as `admin_cidr`.
8. Under **Security groups**, select the value printed as `eks_api_security_group_id` by `terraform output`.
9. Keep the default VPC CNI, CoreDNS, and kube-proxy add-ons and create the cluster.

Wait until the cluster status is **Active**.

## Part 5: Create a managed node group manually

Open the cluster → **Compute** → **Add node group**.

| Setting | Value |
| --- | --- |
| Name | `2048-node-group` |
| Node IAM role | `2048-eks-node-role` |
| AMI | Default Amazon Linux 2023 option |
| Instance type | `t3.medium` |
| Desired / minimum / maximum | `1 / 1 / 2` |
| Subnets | The two private subnet IDs from `terraform output private_subnet_ids` |
| Remote SSH access | Disabled |

Wait for the node group to become **Active**.

## Part 6: Connect kubectl

```bash
aws eks update-kubeconfig --region <your-region> --name 2048-eks-cluster
kubectl get nodes
```

The worker node should show as `Ready`. If the command times out, check whether your public IP changed. Update both the EKS endpoint access CIDR in the console and `admin_cidr` in Terraform if necessary.

## Part 7: Deploy the 2048 game manually

Create these files yourself in a local working folder.

`namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: game-2048
```

`2048-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: game-2048
  namespace: game-2048
spec:
  replicas: 2
  selector:
    matchLabels:
      app: game-2048
  template:
    metadata:
      labels:
        app: game-2048
    spec:
      containers:
        - name: game-2048
          image: blackicebird/2048:latest
          ports:
            - containerPort: 80
```

`2048-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: game-2048
  namespace: game-2048
spec:
  type: LoadBalancer
  selector:
    app: game-2048
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Apply them and wait for the public hostname:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f 2048-deployment.yaml
kubectl apply -f 2048-service.yaml
kubectl get pods,service -n game-2048 --watch
```

Open the Service `EXTERNAL-IP` hostname in your browser once it appears.

## Standard cleanup: stop all charges

Perform cleanup in this order. Terraform cannot destroy the VPC until the manually-created EKS resources are gone.

### A. Delete the game load balancer and Pods

```bash
kubectl delete -f 2048-service.yaml
kubectl delete -f 2048-deployment.yaml
kubectl delete -f namespace.yaml
```

Wait until `kubectl get service -n game-2048` shows no Service. This lets AWS delete the LoadBalancer.

### B. Delete manually-created EKS resources

In the EKS console:

1. Cluster → **Compute** → delete `2048-node-group`; wait until it is deleted.
2. Delete `2048-eks-cluster`; wait until it is deleted.
3. IAM → Roles → delete `2048-eks-node-role` and `2048-eks-cluster-role`.

### C. Destroy the Terraform infrastructure

From the `terraform` directory:

```bash
terraform plan -destroy
terraform destroy
```

Approve only after checking the plan. This removes the NAT gateway, Elastic IP, VPC, subnets, route tables, internet gateway, and Terraform security group.

## Emergency cleanup

If you need to stop costs quickly and cannot use `kubectl`, delete EKS resources first with AWS CLI. Replace the Region and cluster name if you changed them:

```bash
region="ap-south-1"
cluster="2048-eks-cluster"
nodegroup="2048-node-group"

aws eks delete-nodegroup --region $region --cluster-name $cluster --nodegroup-name $nodegroup
aws eks wait nodegroup-deleted --region $region --cluster-name $cluster --nodegroup-name $nodegroup

aws eks delete-cluster --region $region --name $cluster
aws eks wait cluster-deleted --region $region --name $cluster
```

Then run `terraform destroy` from the `terraform` directory. If the node group was never created, skip its two commands. If AWS reports an in-use resource during `terraform destroy`, wait for deletion to finish; do not delete the Terraform state file.
