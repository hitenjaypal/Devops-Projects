# 2048 on EKS: Architecture Explained

This document explains the architecture you are building, not just the commands used to create it.

## Important boundary: Terraform versus manual work

Terraform creates the **network foundation only**:

- VPC, Internet Gateway, subnets, route tables, NAT Gateway, Elastic IP
- EKS discovery tags on subnets
- One additional EKS API security group

Terraform creates **no EKS resources**. There is no `aws_eks_cluster`, `aws_eks_node_group`, `aws_iam_role`, Kubernetes provider, Pod, Deployment, Service, or LoadBalancer resource in `terraform/`.

You create EKS, the IAM roles, node group, and application manually. This boundary is intentional: Terraform gives you fast, repeatable networking while the console work teaches the EKS pieces.

## Architecture diagram

```text
                             Control / administration path
Your laptop + AWS CLI
        |  kubectl over HTTPS (443), only from your public IP
        v
  EKS public API endpoint
        |
        v
  AWS-managed EKS control plane
        |
        | schedules Pods and manages desired state
        v
┌──────────────────────── VPC: 10.20.0.0/16 ───────────────────────┐
│                                                                    │
│  Public subnet A                 Public subnet B                  │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ Internet Gateway │<-----------│ Public Load      │<-- Browser  │
│  └────────┬────────┘            │ Balancer         │              │
│           │                     └─────────────────┘              │
│       ┌───v────────┐                                               │
│       │ NAT Gateway│  outbound-only path for private nodes         │
│       └───┬────────┘                                               │
│           │                                                        │
│  Private subnet A                Private subnet B                 │
│  ┌─────────────────┐           ┌─────────────────┐               │
│  │ EKS worker node  │           │ EKS worker node  │               │
│  │ 2048 Pods        │           │ (capacity / HA)  │               │
│  └─────────────────┘           └─────────────────┘               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Two traffic flows

### 1. A player opens the game

1. The player opens the hostname from the Kubernetes `Service` of type `LoadBalancer`.
2. Kubernetes asks AWS to create a public load balancer in subnets tagged `kubernetes.io/role/elb = 1`.
3. The load balancer forwards HTTP traffic to healthy 2048 Pods on private worker nodes.
4. The Pod returns the game page through the same path to the player.

The worker nodes never need public IP addresses. Only the load balancer is public.

### 2. A worker node pulls the container image

1. The node in a private subnet needs to pull `blackicebird/2048` and contact AWS/EKS services.
2. Its private route table sends `0.0.0.0/0` to the NAT Gateway.
3. The NAT Gateway lives in a public subnet and sends traffic through the Internet Gateway.
4. Response traffic returns to the node, but new internet connections cannot begin directly to the node.

That is why the NAT Gateway is required in this learning architecture.

## Why two subnet types?

| Component                    | Public subnet                       | Private subnet                        |
| ---------------------------- | ----------------------------------- | ------------------------------------- |
| Route to Internet Gateway    | Yes                                 | No                                    |
| Public IP needed             | Load balancer / NAT only            | No                                    |
| Used by                      | NAT Gateway and public LoadBalancer | EKS worker nodes and application Pods |
| Inbound access from internet | Possible when security rules allow  | Not directly possible                 |

The subnet type is decided by its **route table**, not by its name.

## Security model

| Layer           | What protects it                                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------------------------------ |
| Kubernetes API  | EKS endpoint CIDR restriction plus the additional API security group, both limited to your `admin_cidr` on TCP 443 |
| Worker nodes    | Private subnets; no SSH access configured; EKS-managed security-group rules                                        |
| Game traffic    | AWS LoadBalancer sends traffic only to matching healthy Pods                                                       |
| Outbound access | NAT Gateway permits private-subnet initiated outbound connections only                                             |

When manually creating the cluster, set its public endpoint CIDR to the same `admin_cidr` used by Terraform. The security group alone is not a replacement for that EKS endpoint setting.

## Why the subnet tags matter

Terraform sets these tags before EKS exists:

| Tag                                               | Meaning                                                  |
| ------------------------------------------------- | -------------------------------------------------------- |
| `kubernetes.io/role/elb = 1`                      | This public subnet can host a public load balancer.      |
| `kubernetes.io/role/internal-elb = 1`             | This private subnet can host an internal load balancer.  |
| `kubernetes.io/cluster/2048-eks-cluster = shared` | This subnet is shared with the manually-created cluster. |

Tags are metadata. They do not create EKS or a load balancer; they let those manual/EKS actions discover the correct subnets later.

## Availability and cost trade-off

The project uses two Availability Zones, but one NAT Gateway. Your nodes and load balancer can span two AZs, while NAT egress is a single-AZ cost-saving choice. For production, create one NAT Gateway per AZ to avoid that single point of failure. For a hands-on lab, one NAT Gateway is the sensible lower-cost option—destroy it as soon as you finish.

## Resource ownership and cleanup order

```text
Terraform owns: VPC → subnets/routes → NAT/Elastic IP → API security group
Manual EKS owns: IAM roles → EKS cluster → node group
Kubernetes owns: Service → AWS LoadBalancer; Deployment → Pods
```

Delete in reverse dependency order:

1. Kubernetes Service, Deployment, Namespace
2. Manual EKS node group, then EKS cluster, then IAM roles
3. `terraform destroy`
