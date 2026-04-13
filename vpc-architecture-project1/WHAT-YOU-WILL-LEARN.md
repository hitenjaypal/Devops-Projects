# 🧠 What You Will Learn — VPC Architecture Project

> This document maps every hands-on action in the project to the **concept behind it**, so you don't just follow steps — you understand **why** each step exists.

---

## 📐 Architecture Deep-Dive

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        AWS REGION: ap-south-1                                │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                     VPC: 10.0.0.0/16                                  │  │
│  │                                                                        │  │
│  │   ┌─────────────────────────┐      ┌─────────────────────────┐        │  │
│  │   │   PUBLIC SUBNET 1       │      │   PUBLIC SUBNET 2       │        │  │
│  │   │   10.0.1.0/24 | AZ-1a  │      │   10.0.2.0/24 | AZ-1b  │        │  │
│  │   │                         │      │                         │        │  │
│  │   │  ┌─────────────────┐    │      │  ┌──────────────────┐   │        │  │
│  │   │  │  Bastion Host   │    │      │  │  NAT Gateway     │   │        │  │
│  │   │  │  (Jump Server)  │    │      │  │  + Elastic IP    │   │        │  │
│  │   │  │  t3.micro       │    │      │  │                  │   │        │  │
│  │   │  │  Public IP ✅   │    │      │  └────────┬─────────┘   │        │  │
│  │   │  └────────┬────────┘    │      │           │             │        │  │
│  │   └───────────┼─────────────┘      └───────────┼─────────────┘        │  │
│  │               │ SSH (22)                        │ outbound internet    │  │
│  │               │ via SG rule                     │                      │  │
│  │   ┌───────────┼─────────────┐      ┌───────────┼─────────────┐        │  │
│  │   │   PRIVATE SUBNET 1      │      │   PRIVATE SUBNET 2      │        │  │
│  │   │   10.0.3.0/24 | AZ-1a  │      │   10.0.4.0/24 | AZ-1b  │        │  │
│  │   │           │              │      │           │              │        │  │
│  │   │  ┌────────▼────────┐    │      │  ┌────────▼─────────┐   │        │  │
│  │   │  │  Dev Server     │    │      │  │  (Future: DB /   │   │        │  │
│  │   │  │  Nginx + App    │    │      │  │   Backend)       │   │        │  │
│  │   │  │  Private IP only│    │      │  │                  │   │        │  │
│  │   │  │  NO public IP ❌│    │      │  └──────────────────┘   │        │  │
│  │   │  └─────────────────┘    │      │                         │        │  │
│  │   └─────────────────────────┘      └─────────────────────────┘        │  │
│  │                                                                        │  │
│  │  Route Table (Public):  0.0.0.0/0 ──► IGW                             │  │
│  │  Route Table (Private): 0.0.0.0/0 ──► NAT Gateway                     │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                     ▲                                                         │
│            [Internet Gateway]                                                 │
│                     ▲                                                         │
└─────────────────────┼─────────────────────────────────────────────────────── ┘
                      │
              [PUBLIC INTERNET]
                      │
             [Your Local Machine]
```

---

## 📚 Concept Map — What You Learn and Why

### 1. 🌐 VPC (Virtual Private Cloud)

**What it is:**
A logically isolated section of AWS where you control networking end-to-end.

**What you learn:**
- CIDR notation: `10.0.0.0/16` means 65,536 IP addresses available
- How AWS networking differs from a physical data center
- Why isolation matters — workloads in different VPCs can't talk to each other unless explicitly connected

**Real-world parallel:**
> VPC = Your company's private office building. AWS is the city. You own the building; AWS owns the city infrastructure.

```
CIDR Quick Guide:
/16 = 65,536 IPs  (entire project: 10.0.0.0/16)
/24 = 256 IPs     (each subnet:   10.0.1.0/24)
/32 = exactly 1 IP (your local machine in SG rule)
```

---

### 2. 🏢 Subnets — Dividing Your Network

**What it is:**
A subdivision of your VPC's IP space, tied to one Availability Zone.

**What you learn:**

| Type | Purpose | Route to Internet | Has Public IP? |
|------|---------|------------------|----------------|
| **Public** | Internet-facing resources (Bastion, LB, NAT) | Via IGW | Yes (if enabled) |
| **Private** | Protected resources (DBs, app servers) | Via NAT (outbound only) | No |

**Why use 2 of each?**
> High Availability! If AZ-1a goes down, AZ-1b still runs. This is standard AWS best practice. Even for learning, 2 AZs is the right habit.

**What you learn:**
- AZ selection matters for redundancy
- Subnets don't create security by themselves — route tables + security groups create security
- Auto-assign public IP setting is per-subnet

---

### 3. 🚪 Internet Gateway (IGW)

**What it is:**
A horizontally-scaled, redundant, highly available gateway that allows communication between VPC and internet.

**What you learn:**
- Attaching IGW to VPC alone is not enough — you MUST add a route in the route table
- IGW performs NAT for instances with public IPs (one-to-one translation)
- One IGW per VPC

**The magic of IGW:**
```
Instance with public IP (e.g. Bastion: 10.0.1.10)
  → Sends packet to 8.8.8.8
  → IGW translates source IP: 10.0.1.10 → 13.234.56.78 (public IP)
  → Packet goes to internet
  → Response comes back, IGW translates back to private IP
  → Bastion receives response
```

---

### 4. 🔄 NAT Gateway — One-Way Door

**What it is:**
Network Address Translation — allows private instances to initiate outbound connections while blocking inbound.

**What you learn:**
- NAT must be placed in a PUBLIC subnet (it needs internet access itself)
- Private route table: `0.0.0.0/0 → NAT` (not → IGW)
- NAT allows: `dnf update`, `git clone`, `pip install`, `curl` from private EC2
- NAT blocks: random internet traffic from reaching your private server
- NAT replaces source IP of private instance with NAT's Elastic IP

**NAT vs IGW comparison:**

| | NAT Gateway | Internet Gateway |
|-|-------------|-----------------|
| Direction | Outbound only | Both inbound + outbound |
| Subnet | Must be in PUBLIC subnet | Attached to VPC |
| Inbound traffic | ❌ Blocked | ✅ Allowed (via public IP/SG) |
| Use for | Private EC2 internet access | Public-facing resources |
| Cost | ~₹3.75/hr | FREE |

---

### 5. 🗺️ Route Tables — Network GPS

**What it is:**
A set of rules that determine where network traffic is directed.

**What you learn:**
- Every subnet must have exactly one route table
- Route tables are evaluated with longest prefix match first
- `local` route is always present and cannot be deleted
- Routes don't move traffic — they direct it to a gateway which does the moving

**Reading a route table:**
```
Destination    | Target  | Meaning
─────────────────────────────────────────
10.0.0.0/16   | local   | Stay inside VPC (any internal traffic)
0.0.0.0/0     | igw-xxx | Anything else → go to internet via IGW

Why local is first: 10.0.3.5 matches both rows, but /16 is more specific
than 0.0.0.0/0, so local wins → traffic stays inside VPC ✅
```

---

### 6. 🛡️ Security Groups — Stateful Firewalls

**What it is:**
Virtual firewalls for EC2 instances. Rules are stateful — return traffic is automatic.

**What you learn:**
- Difference between stateful (SG) and stateless (NACL) firewalls
- How to reference another SG as a source (instead of IP) — this is powerful
- Principle of least privilege in security group design
- Why port 22 should NEVER be open to `0.0.0.0/0`

**SG Chaining (key concept):**
```
bastion-sg allows: SSH from MY_IP/32
private-ec2-sg allows: SSH from bastion-sg  ← references SG, not IP

This means: ONLY machines in bastion-sg can SSH to private EC2
Even if attacker gets a different machine, they can't SSH in
```

**Stateful explained:**
```
You allow inbound HTTP (port 80) in SG
User sends GET request → Port 80 inbound ✅ (allowed by rule)
Server sends response  → Port 80 outbound ✅ (automatically allowed, no rule needed)
STATEFUL = response traffic is automatically allowed
```

---

### 7. 🏰 Bastion Host (Jump Server) Pattern

**What it is:**
A single, hardened EC2 in a public subnet used exclusively as an SSH entry point.

**What you learn:**
- Why direct public access to application servers is dangerous
- How to SSH tunnel through a bastion: `Local → Bastion → Private EC2`
- Why Bastion's SG restricts port 22 to your IP only
- The trade-off: Bastion is a single point of failure, but also a single point of security enforcement

**Access chain:**
```
Your Machine (Windows)
  │
  │  ssh -i bastion-key.pem ec2-user@BASTION-PUBLIC-IP
  ▼
Bastion Host (public subnet, has public IP)
  │
  │  ssh -i devserver-key.pem ec2-user@PRIVATE-EC2-PRIVATE-IP
  ▼
Dev Server (private subnet, no public IP — only accessible via Bastion)
```

**Modern alternative (learn later):** AWS Systems Manager Session Manager — no SSH, no port 22, no Bastion needed. More secure but more complex.

---

### 8. 🌍 Nginx Web Server

**What it is:**
A high-performance, lightweight web server (alternative to Apache).

**What you learn:**
- How to install and manage Nginx with `systemctl`
- Where Nginx serves files from: `/usr/share/nginx/html/`
- How to check if Nginx is working: `curl http://localhost`
- Nginx vs Apache: both serve static HTML; Nginx is faster for concurrent connections

**Key commands:**
```bash
sudo systemctl start nginx     # Start the server
sudo systemctl enable nginx    # Auto-start on EC2 reboot
sudo systemctl status nginx    # Check if running
sudo systemctl restart nginx   # Restart after config changes

# Log files
/var/log/nginx/access.log     # Every request made to the server
/var/log/nginx/error.log      # Any errors (check first if site doesn't load)

# Web root
/usr/share/nginx/html/        # Put your HTML files here
```

---

### 9. 🔑 SSH Key Pairs and Permissions

**What it is:**
AWS uses asymmetric key pairs (`.pem` files) instead of passwords for EC2 SSH access.

**What you learn:**
- `.pem` file = private key; AWS keeps the public key
- `chmod 400 key.pem` — why this is mandatory on Linux/Mac
- `scp` for copying files securely between machines
- Why you copy the dev server key to Bastion (to then SSH further)

```bash
chmod 400 key.pem          # Owner read-only — SSH refuses if permissions are open
scp -i key.pem file.txt ec2-user@IP:/destination/  # Secure copy
```

---

### 10. 💸 Cloud Cost Engineering

**What you learn:**
- NAT Gateway is billed by time AND data — delete it after each session
- Elastic IP costs money when NOT attached to a running instance
- EC2 stopped ≠ free if EBS volumes are still attached (but EBS is free tier covered)
- Think in "sessions" not "always-on" for learning

**Cost engineering mindset:**
```
Question to ask before EVERY resource you create:
  1. Is this in the free tier? → VPC, IGW, SG, EC2 t3.micro = YES
  2. Is this time-billed? → NAT Gateway = YES ($0.045/hr)
  3. Can I delete this after the session? → NAT + EIP = YES

Rule: If it has an hourly cost, DELETE IT at the end of every session.
```

---

## 🎯 Skills You Gained

| Skill | Professional Relevance |
|-------|----------------------|
| VPC design with public/private subnets | Every AWS production workload |
| Bastion host security pattern | Standard enterprise SSH access model |
| NAT Gateway for private subnet internet | Backend servers, databases, microservices |
| Security Group chaining | Defense in depth, zero-trust networking |
| Nginx deployment | Industry-standard web server for static and reverse proxy |
| SSH key management | Day-1 skill for every DevOps/Cloud role |
| Cost-aware infrastructure design | FinOps — increasingly valued in cloud teams |
| Route table configuration | Core networking for any cloud architect role |

---

## 🗺️ Learning Path From Here

```
[This Project] VPC + Bastion + Nginx
        │
        ▼
[Next] Application Load Balancer (no more direct EC2 exposure)
        │
        ▼
[Next] Auto Scaling (automatic EC2 management)
        │
        ▼
[Next] RDS in Private Subnet (full 3-tier: web + app + DB)
        │
        ▼
[Next] CI/CD with CodePipeline or GitHub Actions (automated deployments)
        │
        ▼
[Next] Containers: ECS or EKS (Kubernetes)
```

---

*Document: WHAT-YOU-WILL-LEARN.md | Project: vpc-architecture-project1 | Region: ap-south-1*
