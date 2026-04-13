# 🏗️ AWS VPC Architecture — Bastion Host + Nginx Deployment

> **Difficulty:** Beginner → Intermediate | **Cost:** ~₹10–15 per session | **Time:** 2–3 hours

A hands-on AWS project that builds a **production-style secure network architecture** from scratch. You will create a custom VPC, configure public and private subnets, deploy a Bastion (Jump) Server, host a development server in a private subnet, and serve a real HTML web application via Nginx — all while keeping AWS costs near zero.

---

## 📌 What This Project Covers

| Area | What You Build |
|------|---------------|
| **Networking** | Custom VPC, 2 public + 2 private subnets, route tables, CIDR blocks |
| **Connectivity** | Internet Gateway (IGW), NAT Gateway, Elastic IP |
| **Security** | Security Groups with least-privilege rules, Bastion Host pattern |
| **Compute** | 2 EC2 instances (Bastion in public, Dev Server in private) |
| **Web Serving** | Nginx on private EC2, serving a static HTML app |
| **Access Pattern** | SSH tunneling: Local → Bastion → Private EC2 |
| **Cost Control** | Create-use-delete pattern, billing alerts, budget thinking |

---

## 🌐 Architecture Diagram

```
                        ┌─────────────────────────────────────────────────────┐
                        │            VPC: 10.0.0.0/16                         │
                        │                                                     │
  INTERNET              │   ┌──────────────────────┐  ┌────────────────────┐ │
     │                  │   │   PUBLIC SUBNET 1    │  │  PUBLIC SUBNET 2   │ │
     │                  │   │   10.0.1.0/24        │  │  10.0.2.0/24       │ │
     ▼                  │   │                      │  │                    │ │
[Internet Gateway]──────┼──►│  [Bastion Host]      │  │  [NAT Gateway]     │ │
     │ igw-0f8334d04    │   │   (Jump Server)      │  │  + Elastic IP      │ │
     │                  │   │   Public IP ✅       │  │                    │ │
     │                  │   └──────────┬───────────┘  └────────┬───────────┘ │
     │                  │              │ SSH (port 22)          │ Outbound    │
     │                  │              ▼                        │ internet    │
     │                  │   ┌──────────────────────┐  ┌────────▼───────────┐ │
     │                  │   │  PRIVATE SUBNET 1    │  │  PRIVATE SUBNET 2  │ │
     │                  │   │  10.0.3.0/24         │  │  10.0.4.0/24       │ │
     │                  │   │                      │  │                    │ │
     │                  │   │  [Dev/App Server]    │  │  (Reserved for     │ │
     │                  │   │   Nginx + Web App    │  │   future DB etc.)  │ │
     │                  │   │   NO public IP ❌    │  │                    │ │
     │                  │   └──────────────────────┘  └────────────────────┘ │
     │                  │                                                     │
     │                  │   Route Table - Public:  0.0.0.0/0 → IGW           │
     │                  │   Route Table - Private: 0.0.0.0/0 → NAT Gateway   │
     │                  └─────────────────────────────────────────────────────┘
     │
     └── Users access site via Bastion's Public IP (port 80 via Nginx)
```

### Traffic Flow Summary

| Journey | Path | Why |
|---------|------|-----|
| **Developer SSH access** | Local Machine → IGW → Bastion → Private EC2 | Bastion is the only entry point |
| **Private EC2 downloads** | Private EC2 → NAT → IGW → Internet | NAT allows outbound, blocks inbound |
| **Web traffic (Nginx)** | User browser → IGW → Bastion (port 80) → (optional relay) | Static site served via Nginx |
| **Git clone on private EC2** | Private EC2 → NAT → GitHub | Outbound allowed through NAT |

---

## 🔌 Core Networking Concepts (How It All Connects)

### 1. VPC — Your Isolated Network
```
CIDR: 10.0.0.0/16 = 65,536 IP addresses
Think of it as: Your private city inside AWS
Nobody from outside can enter unless YOU open a gate (IGW / SG rules)
```

### 2. Subnets — Floors in Your Building
```
Public Subnets  (10.0.1.0/24, 10.0.2.0/24)
  → Have a route to IGW → Can reach internet
  → Hosts: Bastion, NAT Gateway, Load Balancer

Private Subnets (10.0.3.0/24, 10.0.4.0/24)
  → No direct route to IGW → Cannot be reached from internet
  → Hosts: Dev Server, Database, Backend apps
```

### 3. Internet Gateway — The Main Door
```
IGW connects your VPC to the public internet.
Rule: A subnet is "public" ONLY if its route table has: 0.0.0.0/0 → IGW
Without this route, even attaching an IGW does nothing.
```

### 4. NAT Gateway — One-Way Mirror for Private Subnets
```
Placed IN a public subnet (has internet access via IGW)
Private subnet route: 0.0.0.0/0 → NAT

What NAT does:
  ✅ Private EC2 sends request OUT  (e.g., git clone, dnf update)
  ❌ Internet CANNOT send requests IN to private EC2

Analogy: Like a postal box — you can send letters out, but no one knows your home address
```

### 5. Route Tables — The GPS / Traffic Director
```
Each subnet is associated with exactly ONE route table.

Public Route Table:
  Destination    | Target
  10.0.0.0/16    | local   ← Internal VPC traffic stays local
  0.0.0.0/0      | igw-xxx ← Everything else goes to internet

Private Route Table:
  Destination    | Target
  10.0.0.0/16    | local   ← Internal VPC traffic stays local
  0.0.0.0/0      | nat-xxx ← Everything else goes through NAT
```

### 6. Security Groups — Personal Bodyguards per Instance
```
Bastion Security Group:
  Inbound:  SSH (22) from YOUR_IP/32 only
  Outbound: ALL (default)

Private EC2 Security Group:
  Inbound:  SSH (22) from Bastion-SG-ID only  ← KEY: references SG, not IP
            HTTP (80) from Bastion-SG-ID (for Nginx testing)
  Outbound: ALL (default — needed for NAT to work)

Critical Rule: Security Groups are STATEFUL
  → If you allow inbound traffic, the response is automatically allowed out
  → You never need to add outbound rule for allowed inbound connections
```

### 7. Bastion Host (Jump Server) — The Controlled Entry Point
```
Why Bastion?
  Without Bastion: Developer → Internet → Direct SSH to private EC2 ← IMPOSSIBLE (no public IP)
  With Bastion:    Developer → Bastion (public) → Private EC2 (private IP only)

Security benefit:
  → Only ONE machine (Bastion) is exposed to internet on SSH
  → Private servers are completely shielded
  → Compromise of Bastion ≠ compromise of private servers (SG blocks direct access)
```

---

## ⚙️ Step-by-Step Implementation

### Phase 1 — VPC and Networking

**Step 1: Create VPC**
```
VPC Console → Create VPC
Name: my-vpc-project
IPv4 CIDR: 10.0.0.0/16
Enable DNS Hostnames: YES ✅
Enable DNS Resolution: YES ✅
```

**Step 2: Create Subnets**
```
Subnet 1 (Public):  Name: public-subnet-1   CIDR: 10.0.1.0/24   AZ: ap-south-1a
Subnet 2 (Public):  Name: public-subnet-2   CIDR: 10.0.2.0/24   AZ: ap-south-1b
Subnet 3 (Private): Name: private-subnet-1  CIDR: 10.0.3.0/24   AZ: ap-south-1a
Subnet 4 (Private): Name: private-subnet-2  CIDR: 10.0.4.0/24   AZ: ap-south-1b

For PUBLIC subnets only: Edit subnet → Enable Auto-assign Public IPv4 ✅
```

**Step 3: Create & Attach Internet Gateway**
```
VPC → Internet Gateways → Create IGW
Name: my-igw
Actions → Attach to VPC → Select your VPC
```

**Step 4: Configure Route Tables**
```
Public Route Table:
  Create → Name: public-rt
  Routes: Add 0.0.0.0/0 → igw-xxxxxxxx
  Subnet associations: Associate public-subnet-1 and public-subnet-2

Private Route Table (add NAT route AFTER creating NAT):
  Create → Name: private-rt
  Routes: Add 0.0.0.0/0 → nat-xxxxxxxx  (add this after NAT is created)
  Subnet associations: Associate private-subnet-1 and private-subnet-2
```

---

### Phase 2 — NAT Gateway

**Step 5: Allocate Elastic IP**
```
EC2 → Elastic IPs → Allocate Elastic IP Address
Note the allocated IP
```

**Step 6: Create NAT Gateway**
```
VPC → NAT Gateways → Create NAT Gateway
Name: my-nat-gateway
Subnet: public-subnet-1   ← MUST be in a public subnet
Elastic IP: Select the one you just allocated
Click Create → Wait ~2 minutes until status = Available
```

**Step 7: Update Private Route Table**
```
VPC → Route Tables → private-rt → Routes → Edit routes
Add: 0.0.0.0/0 → nat-xxxxxxxx
Save
```

---

### Phase 3 — Security Groups

**Step 8: Bastion Security Group**
```
EC2 → Security Groups → Create
Name: bastion-sg
VPC: your vpc

Inbound Rules:
  SSH | TCP | 22 | My IP (x.x.x.x/32)   ← Your current IP only
```

**Step 9: Private EC2 Security Group**
```
Name: private-ec2-sg

Inbound Rules:
  SSH  | TCP | 22 | Source: bastion-sg   ← Reference the SG, not an IP!
  HTTP | TCP | 80 | Source: 0.0.0.0/0    ← For Nginx web serving
```

---

### Phase 4 — EC2 Instances

**Step 10: Bastion Host (Public Subnet)**
```
EC2 → Launch Instance
Name: bastion-host
AMI: Amazon Linux 2023
Type: t3.micro
Key Pair: Create new → bastion-key.pem (SAVE IT!)
Network: your-vpc | Subnet: public-subnet-1
Auto-assign Public IP: ENABLE ✅
Security Group: bastion-sg
Launch
```

**Step 11: Dev Server (Private Subnet)**
```
EC2 → Launch Instance
Name: dev-server
AMI: Amazon Linux 2023
Type: t3.micro
Key Pair: Create new → devserver-key.pem (SAVE IT!) OR reuse bastion-key.pem
Network: your-vpc | Subnet: private-subnet-1
Auto-assign Public IP: DISABLE ❌
Security Group: private-ec2-sg
Launch
```

---

### Phase 5 — SSH Access via Bastion

**Step 12: Copy Private Key to Bastion**

```bash
# On your Windows machine (Git Bash):
scp -i bastion-key.pem devserver-key.pem ec2-user@<BASTION-PUBLIC-IP>:/home/ec2-user/
```

**Step 13: SSH into Bastion**
```bash
ssh -i bastion-key.pem ec2-user@<BASTION-PUBLIC-IP>
```

**Step 14: SSH from Bastion into Private Dev Server**
```bash
# Now you're inside Bastion. From here:
chmod 400 devserver-key.pem
ssh -i devserver-key.pem ec2-user@<PRIVATE-EC2-PRIVATE-IP>
# Use the PRIVATE IP (10.0.3.x), NOT a public IP
```

Test internet on private EC2:
```bash
ping google.com          # Should work via NAT Gateway
curl http://checkip.amazonaws.com   # Returns NAT Gateway's public IP
```

---

### Phase 6 — Install Nginx and Deploy Web App

**Step 15: Install Nginx on Private Dev Server**

```bash
# On private EC2 (after SSHing in via Bastion):
sudo dnf update -y
sudo dnf install -y nginx git

sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```

**Step 16: Clone and Deploy the Web App**

```bash
# Clone from GitHub
git clone https://github.com/YOUR-USERNAME/DevOps-Projects.git /home/ec2-user/project

# Copy HTML app to Nginx web root
sudo cp -r /home/ec2-user/project/DevOps-Project-02/html-web-app/* /usr/share/nginx/html/

# Fix ownership and permissions
sudo chown -R nginx:nginx /usr/share/nginx/html/
sudo chmod -R 755 /usr/share/nginx/html/

# Reload Nginx
sudo systemctl restart nginx
```

**Step 17: Verify Web App is Serving**

```bash
# From inside private EC2:
curl http://localhost           # Should return your HTML content
curl http://localhost/index.html

# Check Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## 🧪 Test Cases

### Infrastructure Tests
```bash
# 1. From Bastion: can you reach private EC2?
ssh -i devserver-key.pem ec2-user@<PRIVATE-IP>     # Should succeed

# 2. From Private EC2: outbound internet (via NAT)?
ping google.com                                      # Should work
curl http://checkip.amazonaws.com                   # Returns NAT's IP

# 3. Try to SSH private EC2 from internet directly
ssh -i key.pem ec2-user@<PRIVATE-IP-OR-ANY-PUBLIC>  # Should FAIL (good!)
```

### Nginx App Tests
```bash
# On private EC2:
curl http://localhost                 # Returns HTML ✅
sudo systemctl status nginx          # active (running) ✅
ls /usr/share/nginx/html/            # Shows index.html, css/, js/, images/ ✅
sudo tail -5 /var/log/nginx/access.log  # Shows GET 200 requests ✅
```

---

## 🔴 Challenges & Solutions

| # | Problem | Cause | Fix |
|---|---------|-------|-----|
| 1 | `WARNING: UNPROTECTED PRIVATE KEY FILE` | Key file too-open permissions | `chmod 400 key.pem` |
| 2 | SSH connection timeout to Bastion | IP mismatch in SG or no IGW route | Update SG with your correct IP |
| 3 | Cannot SSH private EC2 from internet | By design — no public IP, SG blocks it | Use Bastion as jump server ✅ |
| 4 | `apt: command not found` | Amazon Linux uses `dnf` not `apt` | `sudo dnf install -y <package>` |
| 5 | `git: command not found` | Git not pre-installed on EC2 | `sudo dnf install -y git` |
| 6 | GitHub auth failed | Password auth removed by GitHub | Use Personal Access Token (PAT) |
| 7 | Nginx not serving site | Files in wrong directory | Copy to `/usr/share/nginx/html/` |
| 8 | NAT not working for private EC2 | Missing 0.0.0.0/0 → NAT in private RT | Edit private route table |
| 9 | CloudWatch billing metrics missing | Must be in us-east-1 region | Switch region for billing metrics |

---

## 💰 Cost Strategy — Think Before You Spend

### Golden Rule: Only NAT Gateway Costs Money

| Resource | Cost |
|----------|------|
| VPC + Subnets + IGW + Route Tables | **₹0 always** |
| Security Groups | **₹0 always** |
| EC2 t3.micro (free tier) | **₹0** |
| Elastic IP (attached to NAT) | **₹0** |
| Nginx web server | **₹0** |
| **NAT Gateway** | **~₹3.75/hour** ← Only real cost |

### 🧠 Cost-Conscious Engineering Mindset

```
Before creating NAT: Ask → "Do I actually need private subnets for this task?"
  For production apps   → YES, use private subnets + NAT
  For a quick demo      → NO, just use public subnet + direct access

During session:
  → Create NAT only when you need private subnet internet (git clone, dnf update)
  → Do all package installs in one session — don't start/stop NAT repeatedly

After session:
  → STOP EC2 (not terminate — your files stay)
  → DELETE NAT Gateway
  → RELEASE Elastic IP
  → VPC/Subnets/IGW → Leave them (₹0)

Budget per session: ~₹10-15 for 2-3 hours
Monthly budget if doing 4 sessions: ~₹40-60
```

### Set a Billing Alert (Do This First!)

```
AWS Console → Billing → Budgets → Create Budget
Type: Cost Budget
Amount: $5
Alert: 80% of budget → Email you
```

---

## 🧹 Cleanup (Delete in This Exact Order)

```
1. Terminate both EC2 instances
2. Delete NAT Gateway
3. Release Elastic IP
4. Detach + Delete Internet Gateway
5. Delete Subnets (all 4)
6. Delete Route Tables (custom ones only)
7. Delete Security Groups (custom ones only)
8. Delete the VPC
```
> Wait 2 minutes between steps 1 and 2 — NAT needs EC2 to terminate first.

---

## 📁 Project Structure

```
vpc-architecture-project1/
├── README.md                      ← You are here
├── WHAT-YOU-WILL-LEARN.md         ← Concepts + Architecture deep-dive
├── INTERVIEW-QUESTIONS.md         ← 30 VPC interview Q&A
└── html-web-app/                  ← The deployed web application
    ├── index.html
    ├── header.html
    ├── css/
    ├── js/
    └── images/
```

---

## 🔜 Future Improvements

| Enhancement | What it Adds |
|-------------|-------------|
| **CI/CD Pipeline** | Auto-deploy on every GitHub push |
| **AWS SSM Session Manager** | SSH without a Bastion Host or open port 22 |
| **Application Load Balancer** | Distribute traffic, no direct EC2 exposure |
| **Auto Scaling Group** | Scale EC2s up/down with traffic |
| **RDS in Private Subnet** | Proper separated database tier |
| **Docker + ECS** | Containerized deployment |
| **CloudFront + S3** | Serve static site globally, no EC2 needed |

---

*Project by: Hiten Jaypal | Stack: AWS VPC + EC2 + NAT + Nginx | Region: ap-south-1*
