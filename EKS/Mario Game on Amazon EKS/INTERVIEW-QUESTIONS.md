# Mario EKS Project: Interview Questions

## Terraform and EKS

### 1. What does Terraform manage in this project?

Terraform creates the EKS cluster, managed node group, IAM roles and policy attachments, cluster security group, CloudWatch log group, OIDC provider, and an IAM role for AWS Load Balancer Controller. See `EKS-TF/main.tf`.

### 2. What is the difference between `data` and `resource` blocks here?

`data "aws_vpc" "default"` and `data "aws_subnets" "public"` read existing default-network resources. `resource "aws_eks_cluster" "eks_cluster"` creates a new EKS cluster. Data sources do not create AWS infrastructure.

### 3. Why does the EKS cluster role trust `eks.amazonaws.com`?

The EKS service assumes this role to manage the control plane on behalf of your account. The node-group role instead trusts `ec2.amazonaws.com`, because EC2 worker instances assume it.

### 4. Why are IAM policy attachments separate resources?

Each attachment grants one AWS-managed policy to a role. Terraform can then track each permission relationship independently.

### 5. What does `depends_on` solve in the EKS cluster resource?

It ensures required IAM policy attachments exist before cluster creation. Terraform usually infers dependencies from direct references, but these policies are a required relationship not represented by the `role_arn` alone.

### 6. What is a managed node group?

It is an EC2 worker-node group whose lifecycle is managed by EKS. EKS handles node provisioning, upgrades, and health integration, while you choose instance type and scaling limits.

### 7. Does HPA scale worker nodes?

No. HPA changes Pod replicas only. Worker-node autoscaling requires another component such as Cluster Autoscaler or Karpenter; neither is installed by this repository.

### 8. What does the OIDC provider enable?

It allows a Kubernetes ServiceAccount to exchange its token for a scoped AWS IAM role (IRSA), avoiding broad AWS permissions on every worker node.

## Networking and security

### 9. Why is using `0.0.0.0/0` for EKS public API access risky?

It allows any internet address to reach the Kubernetes API endpoint. Authentication still applies, but this unnecessarily exposes the API. Restrict it to your public IP in `/32` form.

### 10. What makes the node subnets public in this project?

The Terraform data source selects default-VPC subnets with `map-public-ip-on-launch = true`. This is simpler for a demo but less isolated than private-node subnets behind NAT.

### 11. What is the role of a Service of type `LoadBalancer`?

It creates a stable Kubernetes endpoint and asks the AWS integration to provision an external load balancer. The Service selector forwards traffic only to matching ready Pods.

### 12. Why do Service selectors and Deployment labels need to match?

The Service finds its endpoints using labels. Here it selects `app: mario` and `version: v1`, so Pods must carry both labels.

### 13. What does `externalTrafficPolicy: Local` trade off?

It preserves source client IP, but only sends traffic to nodes that have local ready Pods. This can produce uneven traffic if Pods are distributed unevenly.

## Kubernetes workload

### 14. Deployment vs Pod?

A Pod is a running unit of containers. A Deployment creates and maintains a requested number of matching Pods through a ReplicaSet and supports rolling updates.

### 15. Explain readiness, liveness, and startup probes.

Startup prevents liveness/restarts while the app is booting. Readiness controls whether a Pod receives Service traffic. Liveness restarts a running container that repeatedly fails its health check.

### 16. Why are resource requests important for this project?

The scheduler uses requests to place Pods, and HPA's utilisation calculation needs resource requests. Limits prevent a container from consuming unlimited CPU or memory.

### 17. Does adding a NetworkPolicy guarantee traffic is blocked?

No. The installed CNI must enforce NetworkPolicy. You must also verify that its selectors and allowed DNS/egress rules match the environment.

### 18. What is a ServiceMonitor?

It is a Prometheus Operator custom resource that tells Prometheus what Service endpoints to scrape. It is not a native Kubernetes object and needs the operator/CRD installed.

## State, operations, and cost

### 19. Why does the S3 backend need to exist before `terraform init`?

Terraform initialises its backend before it can apply resources. A configuration cannot use its own not-yet-created S3 bucket as state storage.

### 20. Why must you delete the Kubernetes Service before `terraform destroy`?

The Service owns a billable AWS load balancer. Deleting it first triggers load-balancer cleanup and removes dependencies that could block cluster/VPC teardown.

### 21. What is the cost danger in this project?

The EKS control plane, two default `t3.medium` nodes, CloudWatch logs, public NLB, and EBS storage all continue billing while alive. The default desired node count is two, not one.

### 22. What is the safest Terraform habit before creating or deleting resources?

Run `terraform plan` before apply and `terraform plan -destroy` before destroy. Read the output instead of using `-auto-approve` while learning.
