# Super Mario on EKS: Architecture Explained

This project is a **full Terraform EKS project**. Unlike the 2048 learning project, Terraform creates the EKS control plane and managed node group in addition to IAM, logging, and selected networking resources.

## What Terraform creates

`EKS-TF/main.tf` defines these AWS resources:

- EKS cluster IAM role and policy attachments
- An EKS cluster security group
- EKS control plane, using the account's **default VPC** and its public subnets
- Managed EKS node-group IAM role and policy attachments
- Managed node group running EC2 worker nodes
- CloudWatch log group for EKS control-plane logs
- IAM OIDC provider and an IAM role intended for AWS Load Balancer Controller

The Kubernetes YAML files are applied separately with `kubectl`; Terraform does not apply them.

## Architecture diagram

```text
Terraform
  |
  +--> Default VPC + public subnets (looked up, not created)
  |       |
  |       +--> EKS control-plane network interfaces
  |       +--> managed node group (EC2 worker nodes)
  |
  +--> IAM roles, CloudWatch log group, OIDC provider
  |
  +--> EKS cluster
             |
Your Ubuntu laptop -- aws eks update-kubeconfig --> Kubernetes API
             |
             +--> kubectl applies Deployment, Service, HPA, NetworkPolicy
                                             |
Browser --> internet-facing NLB --> mario-service --> Mario Pods on worker nodes
```

## Two separate control loops

### Terraform / AWS control loop

Terraform compares `.tf` files with `terraform.tfstate` and creates or changes AWS resources. It manages the cluster infrastructure.

```text
Terraform code -> AWS EKS, IAM, EC2 node group, CloudWatch
```

### Kubernetes control loop

`kubectl apply -f deployment.yaml` sends the desired application state to the EKS API. Kubernetes then keeps that state running.

```text
Kubernetes YAML -> Deployment -> ReplicaSet -> Mario Pods
Kubernetes YAML -> Service -> AWS NLB -> selected Pods
Kubernetes YAML -> HPA -> changes Deployment replica count
```

## Request path: opening the Mario game

1. You open the external hostname assigned to `mario-service`.
2. The Service has `type: LoadBalancer` and NLB annotations, so the AWS Load Balancer Controller should provision an internet-facing Network Load Balancer.
3. The NLB sends TCP port 80 traffic to healthy worker-node/Pod targets.
4. `mario-service` selects only Pods labelled `app: mario` and `version: v1`.
5. The Mario container receives the request on its named `http` port, which maps to container port 80.

## Scaling layers

There are two different scaling mechanisms:

| Layer | Resource | What it scales | Project setting |
| --- | --- | --- | --- |
| Application | HPA | Mario Pods | Minimum 3, maximum 10 Pods |
| Compute | EKS node group | EC2 worker nodes | Minimum 1, maximum 4 nodes |

The HPA can request more Pods, but they can remain `Pending` if the node group has insufficient capacity. This project has a node-group maximum, but it does **not** install Cluster Autoscaler or Karpenter; node count will not automatically follow Pod demand.

## Monitoring and logging

- `enabled_cluster_log_types` sends EKS control-plane logs (API, audit, authenticator, controller manager, scheduler) to CloudWatch.
- `service-monitor.yaml` is a Prometheus Operator custom resource. It does nothing unless the Prometheus Operator/CRD is installed.
- Pod annotations beginning `prometheus.io/` are scrape hints; their effect depends on your Prometheus configuration.

## Important preflight notes

This repository is a learning project, not a ready-to-apply production baseline.

1. It currently defaults to EKS `1.29` and Amazon Linux 2 (`AL2_x86_64`). Review and update these to a currently standard-supported EKS version and compatible AMI before applying.
2. It uses the default VPC and public subnets, and the EKS public API CIDR is `0.0.0.0/0`. Restrict this to your public IP `/32` before applying.
3. The Terraform creates only an IAM role intended for AWS Load Balancer Controller; it does not install the controller. The NLB annotations on `service.yaml` require the controller to be installed and correctly configured.
4. NetworkPolicy works only when the cluster networking implementation enforces it. Verify this before treating `network-policy.yaml` as protection.
5. The S3 backend bucket and DynamoDB lock table must already exist before `terraform init`; Terraform cannot create the backend it is using.

## Cleanup ownership

Terraform owns the AWS infrastructure. Kubernetes owns the application objects and their NLB. Delete in this order:

```text
Kubernetes Service / HPA / Deployment / NetworkPolicy
        ↓
Wait for the NLB to be deleted
        ↓
terraform destroy
```

Running `terraform destroy` while the Kubernetes Service remains can fail because the NLB and its resources still depend on the cluster/VPC.
