# 🚀 Automated Terraform Provisioning — Jenkins + Docker Host

This directory contains the automated **Terraform** configuration for `01-jenkins-ci-cd`. It replaces manual EC2 creation steps in the AWS Management Console with a single command workflow.

---

## 🏗️ Architecture Overview

```
                        +-------------------------------------------------+
                        |                AWS Cloud (VPC)                  |
                        |                                                 |
  +------------------+  |  +-------------------+   +--------------------+ |
  |                  |  |  |  Jenkins-Server   |   |    Docker-Host     | |
  |   Developer /    |  |  |    (t2.micro)     |   |     (t2.micro)     | |
  |   Administrator  +--+->| Ports: 22, 8080   |-->|  Ports: 22, 3000   | |
  |                  |  |  | (Java 17, Jenkins)|   | (Docker, Node App) | |
  +------------------+  |  +-------------------+   +--------------------+ |
                        +-------------------------------------------------+
```

### Components Provisioned
1. **Security Groups**:
   - `jenkins-server-sg`: Opens port 22 (SSH) and 8080 (Jenkins Web UI).
   - `docker-host-sg`: Opens port 22 (SSH) and 3000 (Node.js Application).
2. **EC2 Instances**:
   - `Jenkins-Server`: Amazon Linux 2023 instance preconfigured via user-data script with **Java 17 Amazon Corretto**, **Git**, and **Jenkins**.
   - `Docker-Host`: Amazon Linux 2023 instance preconfigured via user-data script with **Docker**, `dockeradmin` user setup, and `/opt/docker` permissions.

---

## 📋 Prerequisites

1. **AWS CLI** installed and configured (`aws configure`).
2. **Terraform** installed (`>= 1.3.0`).
3. An existing **AWS Key Pair** in your selected AWS region (e.g. `us-east-1`).

---

## ⚡ Quickstart Guide

### Step 1: Initialize Terraform

Navigate to the `terraform` folder and initialize the providers:

```bash
cd Projects/Jenkins/01-jenkins-ci-cd/terraform
terraform init
```

### Step 2: Configure Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your AWS SSH key pair name:

```hcl
aws_region         = "us-east-1"
instance_type      = "t2.micro"
key_name           = "your-aws-keypair-name" # Replace with your AWS key pair name
create_docker_host = true
```

### Step 3: Plan & Apply

Preview the resources to be created:

```bash
terraform plan
```

Provision the infrastructure:

```bash
terraform apply -auto-approve
```

---

## 🔑 Post-Deployment Setup

After `terraform apply` finishes:

1. **Retrieve Jenkins Initial Admin Password**:
   SSH into the Jenkins server using the command from the Terraform output:
   ```bash
   ssh -i <path-to-key.pem> ec2-user@<jenkins_public_ip>
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

2. **Access Jenkins UI**:
   Open `http://<jenkins_public_ip>:8080` in your web browser, paste the initial admin password, install recommended plugins, and create your admin account.

3. **Verify Docker Host**:
   SSH into the Docker Host:
   ```bash
   ssh -i <path-to-key.pem> ec2-user@<docker_host_public_ip>
   docker --version
   ls -ld /opt/docker
   ```

---

## 💰 Cost Management & Clean Up

When you are done testing, destroy all resources to avoid unexpected AWS charges:

```bash
terraform destroy -auto-approve
```
