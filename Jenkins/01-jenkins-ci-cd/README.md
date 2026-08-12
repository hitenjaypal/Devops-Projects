# Deploy a Node.js App on a Docker Container using Jenkins on AWS

**In this guide, we are going to deploy a simple Node.js application on a Docker Container built on an EC2 Instance through the use of Jenkins.**
This is a simpler, Node.js-based alternative to the Java/Tomcat project.

### Agenda

* Setup Jenkins Server on AWS EC2
* Integrating GitHub with Jenkins
* Setup Docker Host on AWS EC2
* Integrate Docker with Jenkins via SSH
* Automate the Build and Deployment process using Jenkins

### Prerequisites

* AWS Account & AWS CLI configured
* Terraform installed (`>= 1.3.0`)
* GitHub Account with the Node.js source code (from this folder)

---

## ⚡ Option A: Automated Provisioning with Terraform (Recommended)

Instead of manually creating EC2 instances in the AWS Web Console, you can provision the entire infrastructure (**Jenkins Server** + **Docker Host**) using Terraform in under 2 minutes:

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

## Step 1: Setup Jenkins Server on AWS EC2 Instance (Manual)

1. **Launch an EC2 Instance:**
   - Open AWS EC2 Dashboard and click **Launch Instance**.
   - Name it `Jenkins-Server`.
   - Choose **Amazon Linux 2023** or **Amazon Linux 2**.
   - Select Instance Type: `t2.micro` (free-tier eligible).
   - Create or Select a key pair.
   - Under Network Settings, allow SSH (22) and Custom TCP traffic on port `8080` (for Jenkins).
   
2. **Install Java (Jenkins requires Java to run):**
   Connect to your EC2 instance via SSH and run:
   ```bash
   sudo yum update -y
   sudo yum install java-17-amazon-corretto -y  # Or java-11-openjdk depending on OS
   java -version
   ```

3. **Install and Start Jenkins:**
   ```bash
   sudo wget -O /etc/yum.repos.d/jenkins.repo \
       https://pkg.jenkins.io/redhat-stable/jenkins.repo
   sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
   sudo yum install epel-release -y
   sudo yum install jenkins -y
   sudo systemctl enable jenkins
   sudo systemctl start jenkins
   ```

4. **Access Jenkins UI:**
   - Navigate to `http://<EC2-Public-IP>:8080`
   - Retrieve the initial admin password by running: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
   - Paste the password in the browser, install the suggested plugins, and set up your Admin user.

## Step 2: Integrate GitHub with Jenkins

1. **Install Git on Jenkins Instance:**
   ```bash
   sudo yum install git -y
   git --version
   ```
2. **Jenkins Plugins:**
   - Go to **Manage Jenkins -> Plugins -> Available Plugins**.
   - Ensure the **GitHub Integration** plugin is installed.
3. **Configure Git:**
   - Go to **Manage Jenkins -> Global Tool Configuration**.
   - Under `Git installations`, ensure Git is set up (usually Jenkins finds it automatically, or set the path to `/usr/bin/git`).

*(Note: Unlike the Java project, we do NOT need to configure Maven since we are using Node.js and building our app directly inside Docker!)*

## Step 3: Setup a Docker Host (on a second EC2 Instance)

We need a separate server to run our application as a container.

1. **Launch a second EC2 Instance:**
   - Name it `Docker-Host`.
   - Select `t2.micro` and your key pair.
   - Check Network Settings: Allow SSH (22) and **Custom TCP on port `3000`** (to access our Node app).

2. **Install Docker:**
   Connect to the newly created Docker-Host instance and run:
   ```bash
   sudo yum update -y
   sudo yum install docker -y
   sudo systemctl enable docker
   sudo systemctl start docker
   ```

## Step 4: Integrate Docker with Jenkins

To deploy our code, Jenkins needs SSH access to the Docker-Host to copy files and run Docker commands.

1. **Create a Docker Admin User:**
   On your Docker-Host, run:
   ```bash
   sudo useradd dockeradmin
   sudo passwd dockeradmin
   sudo usermod -aG docker dockeradmin
   ```
   *(To allow password login: edit `/etc/ssh/sshd_config` and set `PasswordAuthentication yes`. Restart SSH with `sudo systemctl reload sshd`.)*

2. **Prepare a Deploy Directory:**
   ```bash
   sudo mkdir -p /opt/docker
   sudo chown -R dockeradmin:dockeradmin /opt/docker
   ```

3. **Jenkins Settings (Publish Over SSH):**
   - In Jenkins, go to **Manage Jenkins -> Plugins -> Available Plugins**. Search for and install the **Publish Over SSH** plugin.
   - Go to **Manage Jenkins -> System**. Scroll down to **Publish over SSH**.
   - Click **Add** to create a new SSH Server:
     - Name: `Docker-Host`
     - Hostname: Keep the Private IP of your Docker-Host (if in the same VPC) or the Public IP.
     - Username: `dockeradmin`
     - Advanced -> Check "Use password authentication, or use a different key" and enter the password you created.
   - Click **Apply and Save**.

## Step 5: Automate Build and Deployment on Docker Container

Finally, let's create the job that pulls the code and builds it.

1. **Create Jenkins Job:**
   - In Jenkins Dashboard, click **New Item**, choose **Freestyle project**, and name it `NodeJS-Docker-Pipeline`.
   
2. **Source Code Management:**
   - Select **Git**.
   - Enter your GitHub Repository URL (where this Node project is hosted).
   
3. **Build Environment / Post-build Actions:**
   - Scroll down to **Post-build Actions** (or Build Environment).
   - Add action: **Send build artifacts over SSH**.
   - SSH Server Name: Select `Docker-Host`.
   - **Source files:** `**/*` (This copies all files from GitHub like `index.js`, `package.json`, `Dockerfile` to the host)
   - **Remove prefix:** leave blank.
   - **Remote directory:** `/opt/docker`
   - **Exec command:** Here we build and run the Docker image using the transferred files!
     ```bash
     cd /opt/docker
     # Stop and remove old container if it exists (so subsequent builds don't fail due to port conflicts)
     docker stop node-server || true
     docker rm node-server || true
     # Build new image and run
     docker build -t nodeapp:v1 .
     docker run -d --name node-server -p 3000:3000 nodeapp:v1
     ```

4. **Trigger the Build:**
   Save the project configuration. Click **Build Now** to manually trigger the pipeline.
   *Optional: You can configure GitHub Webhooks or "Poll SCM" so pushing new code automatically starts this pipeline.*

5. **Verify the Deployment:**
   - After a successful Jenkins build, open your browser.
   - Go to `http://<Docker-Host-Public-IP>:3000/`
   - You should see: **"Hello from Node.js! This is a simple app for Jenkins CI/CD pipeline."**

**Congratulations! You have successfully automated the deployment of a Node.js App via Jenkins and Docker on AWS!**
