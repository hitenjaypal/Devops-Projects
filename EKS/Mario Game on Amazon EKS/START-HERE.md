# Start Here: Mario EKS Learning Runbook

Use Ubuntu commands in this project. Do not begin with `terraform apply -auto-approve`.

## 1. Preflight

```bash
aws sts get-caller-identity
terraform version
kubectl version --client
```

The backend in `EKS-TF/backend.tf` requires an existing S3 bucket named `mario12bucket` and DynamoDB table named `terraform-lock` in `ap-south-1`. Either create those first or temporarily use local state for this learning run; never run against a backend you do not control.

## 2. Review code before applying

```bash
cd EKS-TF
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Before applying, change the EKS version and compatible node AMI choice to currently supported values, restrict the public endpoint CIDR, and decide whether you truly want SSH node access. See `ARCHITECTURE.md` for why.

## 3. Build and connect

```bash
terraform apply
aws eks update-kubeconfig --name EKS_CLOUD --region ap-south-1
kubectl get nodes
```

## 4. Deploy gradually

Apply and verify one component at a time:

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/mario-deployment
kubectl apply -f service.yaml
kubectl get service mario-service --watch
```

Only then apply HPA. Apply NetworkPolicy after confirming the game works, and ServiceMonitor only after confirming Prometheus Operator is installed.

## 5. Destroy safely

```bash
kubectl delete -f service.yaml
kubectl delete -f horizontal-pod-autoscaler.yaml --ignore-not-found
kubectl delete -f network-policy.yaml --ignore-not-found
kubectl delete -f service-monitor.yaml --ignore-not-found
kubectl delete -f deployment.yaml

terraform plan -destroy
terraform destroy
```

Wait for the external load balancer deletion before Terraform destroys the cluster. Keep `terraform.tfstate` and backend state until destruction has completed successfully.
