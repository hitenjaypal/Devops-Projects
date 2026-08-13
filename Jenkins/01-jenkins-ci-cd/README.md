# 🚀 Deploy a Node.js Application on Docker using Jenkins CI/CD on AWS

This project demonstrates how to build and deploy a simple **Node.js application inside a Docker container using Jenkins CI/CD on AWS EC2**.

The architecture uses **two separate EC2 instances**:

```text
                         GitHub
                           │
                           │ git clone / fetch
                           ▼
                  ┌─────────────────┐
                  │  Jenkins Server │
                  │   EC2 Instance  │
                  │                 │
                  │ Jenkins + Java21│
                  │ Git             │
                  └────────┬────────┘
                           │
                           │ SSH
                           │ Publish Over SSH
                           ▼
                  ┌─────────────────┐
                  │   Docker Host   │
                  │   EC2 Instance  │
                  │                 │
                  │ Amazon Linux 23 │
                  │ Docker          │
                  └────────┬────────┘
                           │
                     docker build
                           │
                           ▼
                  ┌─────────────────┐
                  │ Docker Container│
                  │   node-server   │
                  │                 │
                  │    Port 3000    │
                  └─────────────────┘
                           │
                           ▼
              http://<DOCKER-HOST-IP>:3000
```

---

# 📋 Project Agenda

- Set up Jenkins Server on AWS EC2
- Install Java 21 and Jenkins
- Configure Git and GitHub integration
- Set up a separate Docker Host EC2 instance
- Install and configure Docker
- Configure SSH connectivity between Jenkins and Docker Host
- Configure Jenkins Publish Over SSH
- Automatically transfer the Node.js application to the Docker Host
- Build a Docker image
- Run the Node.js application inside a Docker container
- Access the application through port `3000`

---

# 🛠️ Prerequisites

Before starting, make sure you have:

- AWS Account
- AWS CLI configured
- GitHub Account
- A GitHub repository containing the Node.js application
- Terraform installed if you want to provision the EC2 infrastructure using Terraform
- An EC2 SSH key pair

---

# 🏗️ Infrastructure

This project uses **two EC2 instances**.

| Instance       | Purpose                        | OS                | Required Ports |
| -------------- | ------------------------------ | ----------------- | -------------- |
| Jenkins-Server | Jenkins CI/CD server           | Amazon Linux 2023 | 22, 8080       |
| Docker-Host    | Docker build/deployment server | Amazon Linux 2023 | 22, 3000       |

## Jenkins Server

The Jenkins server is responsible for:

1. Pulling source code from GitHub.
2. Maintaining the Jenkins workspace.
3. Connecting to the Docker Host over SSH.
4. Transferring application files.
5. Executing Docker commands on the Docker Host.

## Docker Host

The Docker Host is responsible for:

1. Receiving application files from Jenkins.
2. Building the Docker image.
3. Removing the previous container.
4. Starting the new container.
5. Serving the Node.js application on port `3000`.

---

# ⚙️ Option A — Provision Infrastructure using Terraform

If Terraform is being used for the project, provision the EC2 infrastructure from the Terraform directory.

```bash
cd terraform
```

Create your local Terraform variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the file and provide your AWS configuration, including your EC2 key pair name.

Then initialize Terraform:

```bash
terraform init
```

Review the infrastructure:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

> ⚠️ Never commit `terraform.tfvars` if it contains sensitive values.

A typical `.gitignore` should include:

```gitignore
terraform.tfvars
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
```

> Keep the `.terraform.lock.hcl` only if your project intentionally tracks the Terraform provider lock file. Do not blindly ignore it if you want reproducible provider versions.

---

# 🖥️ Option B — Manually Create the EC2 Instances

If you are not using Terraform, create the instances from the AWS Console.

---

## Step 1 — Create Jenkins Server

Create an EC2 instance with:

```text
Name: Jenkins-Server
AMI: Amazon Linux 2023
Instance type: t2.micro / t3.micro
```

Configure the Security Group:

| Type       | Port | Source  | Purpose        |
| ---------- | ---: | ------- | -------------- |
| SSH        |   22 | Your IP | SSH access     |
| Custom TCP | 8080 | Your IP | Jenkins Web UI |

> 🔐 For learning purposes, avoid opening SSH and Jenkins port `8080` to `0.0.0.0/0` unless absolutely necessary.

---

# ☕ Step 2 — Install Java 21 and Git

SSH into the Jenkins server:

```bash
ssh -i <your-key.pem> ec2-user@<JENKINS-PUBLIC-IP>
```

Update the system:

```bash
sudo dnf update -y
```

Install Java 21:

```bash
sudo dnf install java-21-amazon-corretto -y
```

Install Git:

```bash
sudo dnf install git -y
```

Verify:

```bash
java -version
git --version
```

Jenkins requires a supported Java version. This project uses **Java 21**.

---

# 🔧 Step 3 — Install Jenkins

Add the Jenkins repository:

```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo \
https://pkg.jenkins.io/redhat-stable/jenkins.repo
```

Import the Jenkins key:

```bash
sudo rpm --import \
https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
```

Install Jenkins:

```bash
sudo dnf install jenkins -y
```

Enable and start Jenkins:

```bash
sudo systemctl enable --now jenkins
```

Check the service:

```bash
sudo systemctl status jenkins
```

---

# 🔑 Step 4 — Get the Jenkins Initial Password

Run:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open:

```text
http://<JENKINS-PUBLIC-IP>:8080
```

Then:

1. Enter the initial administrator password.
2. Install the suggested plugins.
3. Create the Jenkins administrator account.
4. Complete the setup.

---

# 🐙 Step 5 — Verify Git on Jenkins

Check:

```bash
git --version
```

Jenkins should be able to execute Git commands.

In Jenkins:

```text
Manage Jenkins
    → Tools
    → Git
```

Make sure Jenkins can locate the Git executable.

Usually:

```text
/usr/bin/git
```

---

# 🐳 Step 6 — Create the Docker Host

Create a second EC2 instance:

```text
Name: Docker-Host
AMI: Amazon Linux 2023
Instance type: t2.micro / t3.micro
```

Security Group:

| Type       | Port | Source                   | Purpose             |
| ---------- | ---: | ------------------------ | ------------------- |
| SSH        |   22 | Your IP / Jenkins access | SSH                 |
| Custom TCP | 3000 | Your IP                  | Node.js application |

---

# 🐳 Step 7 — Install Docker

SSH into the Docker Host:

```bash
ssh -i <your-key.pem> ec2-user@<DOCKER-HOST-PUBLIC-IP>
```

Update packages:

```bash
sudo dnf update -y
```

Install Docker:

```bash
sudo dnf install docker -y
```

Enable and start Docker:

```bash
sudo systemctl enable --now docker
```

Add `ec2-user` to the Docker group:

```bash
sudo usermod -aG docker ec2-user
```

Log out and reconnect so the group membership takes effect.

Verify:

```bash
docker --version
```

Test:

```bash
docker run hello-world
```

---

# 📁 Step 8 — Create the Deployment Directory

On the Docker Host:

```bash
sudo mkdir -p /opt/docker
```

The deployment user used by Jenkins must have permission to write to this directory.

For the setup used in this project:

```bash
sudo chown -R ec2-user:ec2-user /opt/docker
```

Set appropriate permissions:

```bash
sudo chmod 775 /opt/docker
```

Verify:

```bash
ls -ld /opt/docker
```

Expected:

```text
drwxrwxr-x ... ec2-user ec2-user ... /opt/docker
```

---

# 🔐 Step 9 — Configure Jenkins → Docker Host SSH

This project uses the Jenkins **Publish Over SSH** plugin.

Install the plugin:

```text
Manage Jenkins
    → Plugins
    → Available plugins
    → Publish Over SSH
```

Install it and restart Jenkins if required.

---

# 🔗 Step 10 — Configure Docker Host in Jenkins

Go to:

```text
Manage Jenkins
    → System
    → Publish over SSH
```

Add an SSH server.

Example:

```text
Name: Docker-Host
Hostname: <DOCKER-HOST-IP>
Username: ec2-user
```

If Jenkins and Docker Host are in the same VPC, the Jenkins server can communicate with the Docker Host using its **private IP**, provided the security groups allow the connection.

Use the appropriate authentication method for your environment.

> 🔐 Do not use a default password such as `dockeradmin` / `dockeradmin` in a real environment. SSH keys are preferred.

Use **Test Configuration** and make sure Jenkins can connect successfully.

---

# 📦 Step 11 — Understand the Repository Structure

The Node.js application in this project is located inside:

```text
Jenkins/
└── 01-jenkins-ci-cd/
    ├── Dockerfile
    ├── index.js
    ├── package.json
    └── ...
```

This is important because Jenkins checks out the **entire repository** into its workspace.

For example:

```text
/var/lib/jenkins/workspace/NodeJS-Docker-Pipeline/
```

Inside that workspace:

```text
Jenkins/
└── 01-jenkins-ci-cd/
    ├── Dockerfile
    ├── index.js
    └── package.json
```

The Docker Host is a completely separate EC2 instance.

The files must therefore be transferred:

```text
GitHub
   ↓
Jenkins Workspace
   ↓
SSH Publisher
   ↓
Docker Host /opt/docker
```

---

# 🔨 Step 12 — Create Jenkins Job

From the Jenkins dashboard:

```text
New Item
```

Create:

```text
NodeJS-Docker-Pipeline
```

Select:

```text
Freestyle project
```

Click:

```text
OK
```

---

# 🔗 Step 13 — Configure GitHub Repository

Under:

```text
Source Code Management
```

Select:

```text
Git
```

Repository URL:

```text
https://github.com/<username>/<repository>.git
```

Branch:

```text
*/main
```

For a public repository, credentials may not be required.

For a private repository, configure appropriate GitHub credentials.

---

# 🚚 Step 14 — Configure Publish Over SSH

Under:

```text
Post-build Actions
```

select:

```text
Send build artifacts over SSH
```

Select:

```text
Docker-Host
```

## Transfer Set

Because the Node.js application is located in:

```text
Jenkins/01-jenkins-ci-cd/
```

use:

### Source files

```text
Jenkins/01-jenkins-ci-cd/**
```

### Remove prefix

```text
Jenkins/01-jenkins-ci-cd
```

### Remote directory

```text
/opt/docker
```

This causes the application files to be deployed so that the Docker Host contains:

```text
/opt/docker/
├── Dockerfile
├── index.js
├── package.json
└── ...
```

### Important

Create **only one Transfer Set** for this deployment.

Do not accidentally create multiple Transfer Sets containing the same source files.

---

# 🐳 Step 15 — Configure the Deployment Command

Use the following Exec command:

```bash
cd /opt/docker

echo "===== DEPLOYMENT DIRECTORY ====="
pwd
ls -la

echo "===== STOP OLD CONTAINER ====="
docker stop node-server || true

echo "===== REMOVE OLD CONTAINER ====="
docker rm node-server || true

echo "===== BUILD IMAGE ====="
docker build -t nodeapp:v1 .

echo "===== START CONTAINER ====="
docker run -d \
  --name node-server \
  -p 3000:3000 \
  nodeapp:v1

echo "===== CONTAINER STATUS ====="
docker ps
```

The important point is that these commands execute **on the Docker Host**, not on the Jenkins server.

---

# ▶️ Step 16 — Run the Jenkins Build

Click:

```text
Build Now
```

Open:

```text
Console Output
```

The expected flow is:

```text
Git fetch
    ↓
Git checkout
    ↓
SSH connection to Docker Host
    ↓
Transfer application files
    ↓
docker build
    ↓
docker run
    ↓
SUCCESS
```

A successful transfer should show something similar to:

```text
SSH: Connecting with configuration [Docker-Host]
SSH: Transferred X file(s)
```

---

# 🔍 Step 17 — Verify Files on Docker Host

SSH into the Docker Host:

```bash
ssh -i <your-key.pem> ec2-user@<DOCKER-HOST-PUBLIC-IP>
```

Check:

```bash
ls -la /opt/docker
```

You should see:

```text
Dockerfile
index.js
package.json
```

You can also run:

```bash
find /opt/docker -maxdepth 2 -type f -print
```

---

# 🐋 Step 18 — Verify Docker Container

Run:

```bash
docker ps
```

Expected:

```text
node-server
```

Check all containers:

```bash
docker ps -a
```

Check logs:

```bash
docker logs node-server
```

If necessary:

```bash
docker inspect node-server
```

---

# 🌐 Step 19 — Access the Application

Open:

```text
http://<DOCKER-HOST-PUBLIC-IP>:3000/
```

The Node.js application should respond.

Expected application message:

```text
Hello from Node.js! This is a simple app for Jenkins CI/CD pipeline.
```

---

# 🧪 Troubleshooting

## Problem 1 — Jenkins says "Transferred 0 file(s)"

Check the repository structure.

On the Jenkins server:

```bash
cd /var/lib/jenkins/workspace/NodeJS-Docker-Pipeline
```

Then:

```bash
find Jenkins/01-jenkins-ci-cd -maxdepth 2 -type f -print
```

If the files exist, use:

```text
Source files:
Jenkins/01-jenkins-ci-cd/**
```

and:

```text
Remove prefix:
Jenkins/01-jenkins-ci-cd
```

---

# Problem 2 — Jenkins says "Transferred X files", but `/opt/docker` is empty

This is an important troubleshooting case.

First check:

```bash
ls -la /opt/docker
```

Then check whether the files exist anywhere unexpected:

```bash
find / -type f \( -name "Dockerfile" -o -name "package.json" -o -name "index.js" \) 2>/dev/null
```

Also verify the SSH user's permissions:

```bash
whoami
ls -ld /opt/docker
```

The SSH user must be able to write to `/opt/docker`.

For example:

```bash
sudo chown -R ec2-user:ec2-user /opt/docker
sudo chmod 775 /opt/docker
```

Also verify that the Jenkins job has **only one deployment Transfer Set**.

---

# Problem 3 — Docker build fails with "Dockerfile not found"

On Docker Host:

```bash
cd /opt/docker
ls -la
```

The Dockerfile must exist:

```text
/opt/docker/Dockerfile
```

If the Dockerfile is instead located at:

```text
/opt/docker/Jenkins/01-jenkins-ci-cd/Dockerfile
```

then the `Remove prefix` configuration is incorrect.

For this project, the expected structure is:

```text
/opt/docker/
├── Dockerfile
├── index.js
└── package.json
```

---

# Problem 4 — Docker permission denied

Check:

```bash
docker ps
```

If `ec2-user` cannot access Docker, verify:

```bash
groups
```

You should see:

```text
docker
```

If not:

```bash
sudo usermod -aG docker ec2-user
```

Then log out and reconnect.

---

# Problem 5 — Port 3000 is not accessible

Check the container:

```bash
docker ps
```

Check the port mapping:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected:

```text
node-server    0.0.0.0:3000->3000/tcp
```

Then verify the EC2 Security Group allows:

```text
TCP 3000
```

from your IP address.

---

# Problem 6 — Container starts and immediately stops

Check:

```bash
docker ps -a
```

Then:

```bash
docker logs node-server
```

This normally reveals the Node.js application error.

---

# 🧹 Step 20 — Manual Cleanup

To stop the application:

```bash
docker stop node-server
```

Remove the container:

```bash
docker rm node-server
```

Remove the image:

```bash
docker rmi nodeapp:v1
```

Check:

```bash
docker ps -a
docker images
```

---

# 🔄 Complete CI/CD Flow

After everything is configured, the deployment flow is:

```text
Developer
    │
    │ git push
    ▼
GitHub
    │
    │ Jenkins fetch
    ▼
Jenkins Server
    │
    │ Git checkout
    ▼
Jenkins Workspace
    │
    │ Publish Over SSH
    ▼
Docker Host
    │
    │ /opt/docker
    ▼
docker build
    │
    ▼
Docker Image
    │
    │ docker run
    ▼
node-server Container
    │
    ▼
Node.js Application
    │
    ▼
Port 3000
```

---

# 📁 Important Project Structure

The relevant repository structure is:

```text
Devops-Projects/
│
├── Jenkins/
│   └── 01-jenkins-ci-cd/
│       ├── Dockerfile
│       ├── index.js
│       ├── package.json
│       └── ...
│
└── ...
```

Jenkins workspace:

```text
/var/lib/jenkins/workspace/NodeJS-Docker-Pipeline/
```

Docker deployment directory:

```text
/opt/docker/
```

---

# 🔐 Security Notes

This project is intended for learning and demonstration.

For a production implementation:

- Use SSH keys instead of password authentication.
- Do not use passwords such as `dockeradmin`.
- Do not commit AWS credentials to GitHub.
- Do not commit `.pem` private keys.
- Do not commit `terraform.tfvars` when it contains secrets.
- Restrict Security Group rules instead of allowing `0.0.0.0/0`.
- Restrict Jenkins port `8080` to trusted IPs or use a reverse proxy/VPN.
- Use IAM roles instead of hard-coded AWS access keys.
- Use a proper container registry such as Amazon ECR for production deployments.
- Use immutable image tags rather than repeatedly overwriting `nodeapp:v1`.
- Use HTTPS for production applications.

---

# 🎯 Final Result

After completing this project, you will have implemented:

- AWS EC2
- Amazon Linux 2023
- Jenkins
- Java 21
- Git/GitHub
- Docker
- SSH
- Jenkins Publish Over SSH
- Docker image creation
- Docker container deployment
- Node.js application deployment
- Basic CI/CD automation

The final deployment looks like:

```text
GitHub
   ↓
Jenkins
   ↓
SSH
   ↓
Docker Host
   ↓
Docker Build
   ↓
Docker Container
   ↓
Node.js Application
   ↓
Port 3000
```

🎉 **You have built a basic Jenkins → Docker CI/CD deployment pipeline on AWS.**
