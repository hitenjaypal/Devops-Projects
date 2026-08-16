# EKS 2048 Project: Interview Questions and Answers

These questions are based on this specific project. Use the linked source files while explaining the answers.

## Project boundary

### 1. Does Terraform create EKS in this project?

No. Terraform creates only the VPC foundation and an additional security group. There is no `aws_eks_cluster` or `aws_eks_node_group` resource under `terraform/`. EKS, IAM roles, the managed node group, and Kubernetes resources are deliberately created manually.

Read [ARCHITECTURE.md](ARCHITECTURE.md) and `terraform/main.tf` to show this boundary.

### 2. Why use Terraform for the VPC but create EKS manually?

The VPC has many repeatable, error-prone pieces: subnets, routes, Internet Gateway, NAT, tags, and security group rules. Terraform makes those consistent. Creating EKS manually gives hands-on experience with cluster roles, endpoint access, add-ons, node groups, and the EKS console.

### 3. What is Terraform state, and why must you not delete it?

Terraform state maps the `.tf` resources to their real AWS IDs. `terraform destroy` reads it to delete the correct VPC, NAT Gateway, and security group. Deleting state does not delete AWS infrastructure; it only makes Terraform forget it.

## VPC and routing

### 4. What makes a subnet public or private?

Its route table. A public subnet has `0.0.0.0/0` routed to an Internet Gateway. A private subnet has `0.0.0.0/0` routed to a NAT Gateway instead. See `aws_route_table.public` and `aws_route_table.private` in `terraform/main.tf`.

### 5. Why are worker nodes placed in private subnets?

They do not need to accept direct traffic from the internet. The public load balancer receives user traffic and forwards it to Pods on the private nodes. This reduces the attack surface.

### 6. Why is the NAT Gateway placed in a public subnet?

The NAT Gateway needs an Elastic IP and a route through the Internet Gateway to send private-node traffic outward. If it were in a private subnet, it could not reach the internet.

### 7. Is a NAT Gateway required here?

Yes, for this design. Private EKS nodes need outbound access to pull the 2048 image and contact required AWS/EKS services. NAT gives outbound connectivity without giving nodes public IP addresses.

### 8. Why does this lab use only one NAT Gateway when it has two Availability Zones?

It lowers learning-lab cost. It is not fully highly available: an outage in the NAT Gateway's AZ affects egress. Production typically uses one NAT Gateway per AZ.

### 9. What does `cidrsubnet(var.vpc_cidr, 8, count.index)` do?

It derives a smaller subnet CIDR from the VPC CIDR. With `10.20.0.0/16`, adding 8 subnet bits produces `/24` networks. `count.index` makes a different CIDR for each subnet. See `aws_subnet.public` in `terraform/main.tf`.

### 10. Why do we use two Availability Zones?

EKS needs subnets in at least two AZs, and spreading resources provides better resilience than putting everything in one data center location.

## EKS, tags, and security

### 11. What do the Kubernetes subnet tags do?

They allow EKS/load-balancer integration to discover the correct subnets. `kubernetes.io/role/elb = 1` marks public load-balancer subnets; `kubernetes.io/role/internal-elb = 1` marks private/internal ones. Tags do not create a load balancer by themselves.

### 12. What is the purpose of `kubernetes.io/cluster/<cluster-name> = shared`?

It declares the subnet can be used by that EKS cluster. `shared` means the cluster uses the subnet but Terraform still owns the subnet lifecycle.

### 13. Why does Terraform create an `eks_api` security group if the cluster is manual?

It creates a reusable, least-privilege security group ahead of time. During manual EKS cluster creation you select its output ID as an additional security group. It permits only TCP 443 from `admin_cidr`.

### 14. Is the security group enough to secure the EKS public endpoint?

No. Set the EKS cluster's **public endpoint access CIDR** to the same `admin_cidr` during manual creation. Use both controls.

### 15. Why should we not open ports 22, 80, and 8080 to worker nodes?

Nodes are private and should not be administered from the public internet. The LoadBalancer handles HTTP access to the app, and EKS manages the required node/control-plane connectivity. Unnecessary rules increase attack surface.

## Kubernetes application

### 16. What is the difference between a Pod and a Deployment?

A Pod runs one or more containers. A Deployment manages a desired number of identical Pods and replaces failed ones. This project uses a Deployment with two replicas for the 2048 app.

### 17. Why does the Service selector have to match the Deployment label?

The Service finds target Pods using labels. Here both use `app: game-2048`. If they differ, the Service has no endpoints and the load balancer has no application targets.

### 18. What does Service type `LoadBalancer` do on EKS?

It asks the AWS cloud integration to provision a load balancer and gives the Service an external hostname. The user opens this hostname to reach the game.

### 19. What happens if one 2048 Pod fails?

The Deployment observes fewer running replicas than desired and creates a replacement Pod. The Service directs traffic only to ready Pods.

## Terraform workflow and cost

### 20. What is the difference between `terraform plan` and `terraform apply`?

`plan` is a preview: it changes nothing. `apply` makes the actual AWS changes after you approve the plan.

### 21. Why run `terraform plan -destroy` before `terraform destroy`?

It previews exactly what infrastructure will be removed. This is a safety check, especially for a VPC that contains costly network resources.

### 22. Why can `terraform destroy` fail after manual EKS creation?

The manual EKS cluster, node group, network interfaces, or load balancer may still depend on the Terraform VPC. Delete Kubernetes resources and manual EKS resources first, then destroy Terraform resources.

### 23. What is the main recurring cost risk in this project?

The NAT Gateway, EKS control plane, worker nodes, and application LoadBalancer. Delete them in the order specified in `README.md` as soon as practice is complete.
