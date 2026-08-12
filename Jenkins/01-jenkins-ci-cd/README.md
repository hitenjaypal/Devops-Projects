# Deploy a Node.js App on a Docker Container using Jenkins on AWS

**In this guide, we will deploy a simple Node.js application on a Docker Container built on an AWS EC2 Instance using Jenkins CI/CD.**

---

### 📋 Agenda

* Setup Jenkins Server on AWS EC2 (Amazon Linux 2023)
* Integrate GitHub with Jenkins
* Setup Docker Host on AWS EC2
* Integrate Docker with Jenkins via SSH
* Automate the Build and Deployment process using Jenkins

---

### ⚙️ Prerequisites

* AWS Account & AWS CLI configured
* Terraform installed (`>= 1.3.0`)
* GitHub Account hosting this Node.js repository

---

## ⚡ Option A: Automated Provisioning with Terraform (Recommended)

Instead of manually creating EC2 instances in the AWS Web Console, provision the entire infrastructure (**Jenkins Server** + **Docker Host**) using Terraform in under 2 minutes:

```bash
# 1. Navigate to the terraform directory
cd terraform

# 2. Copy variables template and edit your AWS key pair name
cp terraform.tfvars.example terraform.tfvars
# Set key_name = "your-aws-key-name" in terraform.tfvars

# 3. Provision Infrastructure
terraform init
terraform apply -auto-approve
```

> 💡 **User-Data Automation:** Terraform automatically installs Java 17, Git, and Jenkins on `Jenkins-Server`, and installs Docker, configures `dockeradmin`, and sets up `/opt/docker` on `Docker-Host`.

---

## 🛠️ Option B: Manual Infrastructure Setup (AWS Console)

### Step 1: Setup Jenkins Server on AWS EC2 Instance (Amazon Linux 2023)

1. **Launch an EC2 Instance:**
   - Open AWS EC2 Dashboard and click **Launch Instance**.
   - Name: `Jenkins-Server`
   - AMI: **Amazon Linux 2023**
   - Instance Type: `t2.micro` (or `t3.micro`)
   - Select your SSH Key Pair.
   - **Network Settings / Security Group:**
     - Allow **SSH (Port 22)**
     - Allow **Custom TCP (Port 8080)** for Jenkins UI access.

2. **Install Java 21 & Git:**
   Connect to your EC2 instance via SSH and run:
   ```bash
   sudo dnf update -y
   sudo dnf install java-21-amazon-corretto -y
   sudo dnf install git -y
   java -version
   git --version
   ```

3. **Install and Start Jenkins:**
   ```bash
   # Add Jenkins official repository & key
   sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
   sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

   # Install Jenkins via dnf
   sudo dnf install jenkins -y

   # Enable and Start Jenkins
   sudo systemctl enable --now jenkins
   sudo systemctl status jenkins
   ```

4. **Access Jenkins UI:**
   - Open browser: `http://<Jenkins-Server-Public-IP>:8080`
   - Get the initial admin password:
     ```bash
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```
   - Paste the password, click **Install suggested plugins**, and create your Admin user.

---

### Step 2: Integrate GitHub with Jenkins

1. **Verify Plugins:**
   - Go to **Manage Jenkins -> Plugins -> Installed plugins**.
   - Ensure **Git** and **GitHub Integration** plugins are installed (installed by default with suggested plugins).

2. **Configure Git Executable:**
   - Go to **Manage Jenkins -> Tools**.
   - Under **Git**, verify Git path is set (usually auto-detected or `/usr/bin/git`).

---

### Step 3: Setup Docker Host (Second EC2 Instance)

1. **Launch Second EC2 Instance:**
   - Name: `Docker-Host`
   - AMI: **Amazon Linux 2023**
   - Instance Type: `t2.micro`
   - **Security Group:**
     - Allow **SSH (Port 22)**
     - Allow **Custom TCP (Port 3000)** (to access our deployed Node.js web app).

2. **Install and Start Docker:**
   Connect to `Docker-Host` via SSH and run:
   ```bash
   sudo dnf update -y
   sudo dnf install docker -y
   sudo systemctl enable --now docker
   sudo usermod -aG docker ec2-user
   ```

---

### Step 4: Integrate Docker Host with Jenkins via SSH

1. **Create `dockeradmin` Deployment User:**
   On your `Docker-Host` EC2 instance, execute:
   ```bash
   sudo useradd dockeradmin
   echo "dockeradmin:dockeradmin" | sudo chpasswd
   sudo usermod -aG docker dockeradmin

   # Create deployment directory
   sudo mkdir -p /opt/docker
   sudo chown -R dockeradmin:dockeradmin /opt/docker
   sudo chmod -R 775 /opt/docker

   # Enable password authentication for SSH
   sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl reload sshd
   ```

2. **Configure Jenkins Plugin (Publish Over SSH):**
   - In Jenkins, go to **Manage Jenkins -> Plugins -> Available plugins**.
   - Search for **Publish Over SSH**, select it, and click **Install**.
   - Restart Jenkins if prompted (`http://<Jenkins-Server-IP>:8080/restart`).

3. **Configure SSH Server in Jenkins:**
   - Go to **Manage Jenkins -> System**.
   - Scroll down to **Publish over SSH**.
   - Click **Add** next to SSH Servers:
     - **Name:** `Docker-Host`
     - **Hostname:** Private IP (if same VPC) or Public IP of `Docker-Host`.
     - **Username:** `dockeradmin`
     - Click **Advanced...** -> Check **Use password authentication...**
     - **Password:** `dockeradmin`
   - Click **Test Configuration** (should display `Success`).
   - Click **Save**.

---

### Step 5: Create and Configure Jenkins CI/CD Pipeline Job

1. **Create Job:**
   - Click **New Item** on Jenkins Dashboard.
   - Name: `NodeJS-Docker-Pipeline`
   - Select **Freestyle project** $\rightarrow$ Click **OK**.

2. **Source Code Management:**
   - Select **Git**.
   - **Repository URL:** Enter your GitHub repository URL:
     ```text
     https://github.com/your-username/your-repo.name.git
     ```
   - **Branch Specifier:** `*/main` (or `*/master`)

3. **Post-build Actions (Deploy to Docker Host):**
   - Click **Add post-build action** $\rightarrow$ Select **Send build artifacts over SSH**.
   - **SSH Server Name:** Select `Docker-Host`.
   
   > 📌 **Handling Subfolders vs Root Repository:**
   > - **If your project is in a subfolder** (e.g. `Projects/Jenkins/01-jenkins-ci-cd`):
   >   - **Source files:** `Projects/Jenkins/01-jenkins-ci-cd/**`
   >   - **Remove prefix:** `Projects/Jenkins/01-jenkins-ci-cd`
   > - **If your project is at the repository root:**
   >   - **Source files:** `**/*`
   >   - **Remove prefix:** *(leave blank)*
   
   - **Remote directory:** `/opt/docker`
   - **Exec command:**
     ```bash
     cd /opt/docker
     # Stop and remove existing container if running
     docker stop node-server || true
     docker rm node-server || true
     # Build new Docker image and launch container
     docker build -t nodeapp:v1 .
     docker run -d --name node-server -p 3000:3000 nodeapp:v1
     ```

4. **Run Pipeline & Verify:**
   - Click **Save**.
   - Click **Build Now**.
   - Check **Console Output** to verify build success.
   - Open browser at `http://<Docker-Host-Public-IP>:3000/`.
   - You should see: **"Hello from Node.js! This is a simple app for Jenkins CI/CD pipeline."**

---

## 💡 Alternative: Single EC2 Instance Setup (Jenkins + Docker on 1 Server)

If you prefer to run both Jenkins and Docker on **one single EC2 Instance** to save AWS costs:

1. On your `Jenkins-Server`, install Docker:
   ```bash
   sudo dnf install docker -y
   sudo systemctl enable --now docker
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```
2. In your Jenkins Job configuration under **Build Steps** $\rightarrow$ **Execute shell**, enter:
   ```bash
   # Navigate to subfolder if applicable
   cd Projects/Jenkins/01-jenkins-ci-cd || true

   docker stop node-server || true
   docker rm node-server || true
   docker build -t nodeapp:v1 .
   docker run -d --name node-server -p 3000:3000 nodeapp:v1
   ```

---

🎉 **Congratulations! You have automated the deployment of a Node.js Application with Jenkins and Docker!**

