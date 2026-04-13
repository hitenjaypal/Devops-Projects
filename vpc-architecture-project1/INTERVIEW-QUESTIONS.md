# 🎤 VPC & AWS Networking — 30 Interview Questions

> **Level:** Fresher → 2 Years Experience | **For:** DevOps, Cloud, SRE, Platform roles
> Practice answering out loud. The best answers are concise (30–60 seconds) and include a real example.

---

## 🔵 Section 1: VPC Fundamentals (Q1–Q8)

---

**Q1. What is a VPC and why do we need it?**

> VPC (Virtual Private Cloud) is a logically isolated network inside AWS where you have full control over IP addressing, subnets, routing, and security. Without a VPC, all your AWS resources would be exposed on a shared network. VPC lets you build a secure, private environment — like having your own data center inside AWS. In our project, we created a VPC with CIDR `10.0.0.0/16` to host both public and private resources.

---

**Q2. What is a CIDR block? Explain `10.0.0.0/16`.**

> CIDR (Classless Inter-Domain Routing) defines an IP address range. `10.0.0.0/16` means the first 16 bits are fixed (`10.0`), and the remaining 16 bits can vary — giving 2^16 = 65,536 possible IP addresses from `10.0.0.0` to `10.0.255.255`. Each subnet gets a slice of this range, e.g., `10.0.1.0/24` = 256 IPs for one subnet.

---

**Q3. What is the difference between a public subnet and a private subnet?**

> A **public subnet** has a route in its route table pointing to an Internet Gateway (`0.0.0.0/0 → IGW`). Resources here can have public IPs and receive direct internet traffic. A **private subnet** has no route to IGW — it may route through a NAT Gateway for outbound-only access, but it cannot receive inbound internet traffic. In our project, Bastion and NAT were in the public subnet; the dev server was in the private subnet.

---

**Q4. What is an Internet Gateway? Can a VPC have multiple IGWs?**

> An Internet Gateway is a VPC component that enables communication between the VPC and the internet. It's horizontally scaled, redundant, and managed by AWS — no bandwidth limit or availability concern. **No, a VPC can have only one IGW attached at a time.** However, just attaching IGW doesn't make a subnet public; you must also add a route in the route table.

---

**Q5. What is a Route Table and how does longest prefix match work?**

> A Route Table is a set of rules that tell network traffic where to go. When a packet is sent, AWS looks for the most specific matching route (longest prefix match). For example: if routes are `10.0.0.0/16 → local` and `0.0.0.0/0 → IGW`, a packet to `10.0.3.5` matches both, but `/16` is more specific than `/0`, so it takes the `local` route and stays inside the VPC.

---

**Q6. If I attach an Internet Gateway to my VPC, will all subnets automatically get internet access?**

> **No.** Attaching an IGW to a VPC does nothing on its own. You must: (1) Add a route in the subnet's route table pointing `0.0.0.0/0` to the IGW, and (2) Ensure the instance has a public IP or Elastic IP. Only then does the subnet become truly "public". This is a common mistake beginners make.

---

**Q7. How many Availability Zones should you use, and why?**

> Best practice is **at least 2 AZs** for any production workload. If one AZ experiences an outage (hardware failure, power issues), resources in the second AZ continue serving traffic. In our project we created subnets in AZ-1a and AZ-1b. For a learning project, one AZ is sufficient, but the habit of multi-AZ design is important for interviews.

---

**Q8. What happens if you don't enable DNS hostnames in a VPC?**

> If DNS hostnames are disabled, EC2 instances won't get public DNS names like `ec2-13-234-56-78.ap-south-1.compute.amazonaws.com`. Some AWS services (like RDS, EFS) require DNS resolution to work properly. It's always recommended to enable both DNS Hostnames and DNS Resolution when creating a VPC.

---

## 🟢 Section 2: NAT, Bastion, and Security (Q9–Q18)

---

**Q9. What is a NAT Gateway and why is it placed in a public subnet?**

> NAT Gateway allows instances in private subnets to initiate outbound internet connections (for updates, downloads, API calls) while preventing inbound connections from the internet. It must be placed in a **public subnet** because it needs internet access via the IGW to relay private instances' traffic. If you place it in a private subnet, it has no path to the internet and won't work.

---

**Q10. What is the difference between NAT Gateway and Internet Gateway?**

> | | NAT Gateway | Internet Gateway |
> |-|-------------|-----------------|
> | Direction | Outbound only from private to internet | Bidirectional |
> | Who uses it | Private subnet EC2s | Public subnet EC2s |
> | Inbound blocked | Yes | No (depends on SG) |
> | Cost | ~$0.045/hr | Free |
> | Placement | In public subnet | Attached to VPC |

---

**Q11. What is a Bastion Host? Why is it also called a Jump Server?**

> A Bastion Host is a special-purpose EC2 in a public subnet that serves as the only SSH entry point into the private network. It's called a Jump Server because you "jump" through it — SSH to the Bastion first, then SSH from Bastion to private EC2. The benefit: only one machine is exposed to port 22 from the internet, and all access goes through it, making it easier to audit and secure.

---

**Q12. What is a Security Group? Is it stateful or stateless?**

> A Security Group is a virtual firewall that controls inbound and outbound traffic for EC2 instances. It is **stateful** — if you allow inbound traffic on port 80, the response traffic on the ephemeral return port is automatically allowed without needing an outbound rule. Security Groups are instance-level (attached to ENI, not subnet). All rules are allow-only; there is no explicit deny (unlike NACLs).

---

**Q13. What is the difference between Security Groups and Network ACLs?**

> | | Security Group | Network ACL |
> |-|---------------|-------------|
> | Level | Instance (ENI) | Subnet |
> | Stateful | ✅ Yes | ❌ No (must allow both directions) |
> | Rules | Allow only | Allow + Deny |
> | Default | Deny all inbound, allow all outbound | Allow all |
> | Evaluation | All rules evaluated | Rules evaluated in order (numbered) |
>
> For most use cases, Security Groups are sufficient. NACLs add a subnet-level layer for compliance-heavy environments.

---

**Q14. What does it mean to allow SSH "from a Security Group" instead of from an IP?**

> Instead of allowing `SSH from 10.0.1.0/24`, you can allow `SSH from bastion-sg`. This means only EC2 instances that are associated with `bastion-sg` can SSH into your private EC2, regardless of their IP. This is more secure and flexible — if you scale up Bastions, the new ones automatically get access. It's a pattern called **Security Group referencing** or **SG chaining**.

---

**Q15. What is an Elastic IP? When does it cost money?**

> An Elastic IP (EIP) is a static, public IPv4 address in AWS that you own. It's useful because EC2's default public IP changes every time you stop/start the instance. **Cost:** EIP is FREE when attached to a running EC2 instance. It costs $0.005/hour when allocated but NOT attached (or attached to a stopped instance). Always release EIPs when your project is deleted.

---

**Q16. Can a private EC2 instance have any kind of internet access?**

> Yes, via **NAT Gateway**. The private EC2 sends outbound requests (e.g., `git clone`) → traffic hits the private route table → routes to NAT → NAT forwards to IGW → reaches internet. Response comes back through NAT → to private EC2. The internet sees the NAT's Elastic IP, not the private EC2's IP. This means the private EC2 can reach the internet but cannot be reached from the internet.

---

**Q17. What is the principle of least privilege in the context of security groups?**

> Least privilege means granting only the minimum permissions required and nothing more. In our project:
> - Bastion SG: SSH only from my personal IP (not from all IPs)
> - Private EC2 SG: SSH only from Bastion SG (not the whole internet or even the whole VPC)
> - Nginx port 80: open to `0.0.0.0/0` (web traffic must be public)
> This minimizes the attack surface — a compromised Bastion cannot be used to pivot elsewhere because private SG only allows that specific SG.

---

**Q18. What's the difference between stopping and terminating an EC2 instance?**

> **Stop:** Instance shuts down but its EBS root volume is preserved. Private IP stays the same. Public IP may change (unless EIP is attached). Billed for EBS storage but not compute. Can restart anytime.
>
> **Terminate:** Instance is deleted permanently. Root EBS volume is deleted (by default). All data is gone. Cannot restart.
>
> For learning projects: **Stop** between sessions (preserves your Nginx setup), **Terminate** only when completely done with the project.

---

## 🟡 Section 3: Nginx, Deployment, and GitHub (Q19–Q24)

---

**Q19. What is Nginx and how is it different from Apache?**

> Nginx is a web server known for high concurrency and low memory usage. It uses an event-driven, non-blocking architecture. Apache uses a thread-per-request model. For serving static files (HTML, CSS, JS), both work fine, but Nginx handles many simultaneous connections more efficiently. Nginx is also widely used as a **reverse proxy** — forwarding requests to backend apps (Node.js, Python, etc.). In our project, Nginx served the static HTML web app.

---

**Q20. Where does Nginx serve files from by default on Amazon Linux?**

> `/usr/share/nginx/html/` — this is the default web root on Amazon Linux when Nginx is installed via `dnf`. Files placed here are automatically served at `http://<server-ip>/`. On Ubuntu, the default is `/var/www/html/`.

---

**Q21. What is the difference between `systemctl start` and `systemctl enable`?**

> - `systemctl start nginx` → Starts Nginx **right now** (this session only)
> - `systemctl enable nginx` → Configures Nginx to **automatically start on every boot**
>
> You need both. If you only do `start`, Nginx stops when EC2 reboots. If you only do `enable`, Nginx won't be running now. Always run both after installing a service.

---

**Q22. How do you copy files from your local machine to an EC2 instance?**

> Using `scp` (Secure Copy Protocol):
> ```bash
> scp -i key.pem -r /local/folder/ ec2-user@PUBLIC-IP:/remote/destination/
> ```
> - `-i key.pem` → authentication key
> - `-r` → recursive (for folders)
> - `ec2-user` → default username for Amazon Linux
>
> Alternative methods: Git clone from GitHub (recommended for DevOps), AWS CLI S3 copy, rsync.

---

**Q23. Why can't you use a password to authenticate to GitHub anymore?**

> GitHub removed password authentication for Git operations in August 2021 for security reasons. You must use one of:
> - **Personal Access Token (PAT)** — like a password but with specific scopes and expiry
> - **SSH key** — add your public key to GitHub, use private key locally (most secure)
> - **GitHub CLI** — authenticates via browser
>
> PAT usage: `git clone https://github.com/user/repo.git` → when prompted for password, enter the PAT instead.

---

**Q24. What is the difference between using `chmod 400` vs `chmod 600` on a `.pem` file?**

> - `chmod 400` → Owner can **read only** (no write, no execute)
> - `chmod 600` → Owner can **read and write**
>
> SSH requires the key file to not be accessible by others. Both `400` and `600` satisfy SSH's strict permission check. `400` is more restrictive (read-only) and preferred since you never need to modify a private key. SSH will refuse to use a key file with permissions `644`, `755`, or anything group/other-accessible.

---

## 🔴 Section 4: Design, Cost & Advanced (Q25–Q30)

---

**Q25. How would you design a 3-tier architecture in AWS VPC?**

> Classic 3-tier:
> ```
> Tier 1 (Presentation): ALB in public subnet, EC2/containers behind it
> Tier 2 (Application):  EC2/ECS in private subnet (only ALB can reach it)
> Tier 3 (Database):     RDS in private subnet (only app tier can reach it)
> ```
> Each tier has its own security group. The Database SG only allows MySQL/PostgreSQL from the App SG. This way, a compromised web server cannot directly query the database — it must go through the application layer.

---

**Q26. What is VPC Peering and when would you use it?**

> VPC Peering is a network connection between two VPCs (same or different accounts/regions) that allows traffic to route using private IP addresses. Use cases:
> - Shared services VPC (logging, monitoring) accessed by multiple app VPCs
> - Cross-account access between dev and prod
> - Merging infrastructures after acquisitions
>
> Limitation: VPC Peering is NOT transitive — if VPC-A peers with VPC-B, and VPC-B peers with VPC-C, VPC-A cannot reach VPC-C through VPC-B.

---

**Q27. What is the difference between VPC Peering and AWS Transit Gateway?**

> | | VPC Peering | Transit Gateway |
> |-|-------------|----------------|
> | Connectivity | One-to-one | Hub-and-spoke (many VPCs) |
> | Transitive | ❌ No | ✅ Yes |
> | Setup | Simple | More complex |
> | Cost | Free (data transfer costs apply) | $0.05/hr per attachment + data |
> | Scale | Up to ~100 peering connections | Thousands of VPCs |
>
> Use Peering for simple 2-VPC connections. Use Transit Gateway when connecting many VPCs or on-premises networks.

---

**Q28. A private EC2 can't reach the internet. How do you troubleshoot?**

> Systematic troubleshooting:
> 1. **Route Table**: Does private subnet's route table have `0.0.0.0/0 → NAT`?
> 2. **NAT Gateway**: Is it `Available`? Is it in a PUBLIC subnet?
> 3. **Public Route Table**: Does the NAT Gateway's subnet have `0.0.0.0/0 → IGW`?
> 4. **Elastic IP**: Does NAT have an EIP attached?
> 5. **Security Group outbound**: Is outbound traffic allowed from private EC2?
> 6. **OS-level**: Is the network interface up? (`ip addr show`)
> 7. **Test**: `curl http://checkip.amazonaws.com` — if it returns NAT's IP, all is working.

---

**Q29. How would you reduce NAT Gateway costs in a production environment?**

> Several strategies:
> 1. **Use VPC Endpoints** for AWS services (S3, DynamoDB) — traffic stays inside AWS, doesn't go through NAT → free
> 2. **Consolidate NAT Gateways**: One NAT per AZ (for HA), not one per subnet
> 3. **Use PrivateLink** for service-to-service communication within AWS
> 4. **NAT Instance** (legacy): An EC2 instance running NAT — cheaper but not managed, not recommended for production
> 5. **Compress data**: Less data through NAT = lower data processing charges
> 6. **Session-based approach** (for learning): Create NAT only when needed, delete after

---

**Q30. What is the difference between public IP, Elastic IP, and private IP in AWS?**

> | | Private IP | Public IP | Elastic IP |
> |-|-----------|-----------|------------|
> | Assigned by | AWS from CIDR | AWS from pool | You allocate from AWS |
> | Changes on stop/start | ❌ No (same) | ✅ Yes (new IP) | ❌ No (fixed) |
> | Reachable from internet | ❌ No | ✅ Yes | ✅ Yes |
> | Cost | Free | Free | Free if attached to running instance; $0.005/hr if not |
> | Use case | Internal VPC comms | Temporary public access | Production servers, NAT |
>
> **Key rule:** Always use an Elastic IP if you need a stable, shareable public address (e.g., for DNS records, client whitelisting). Use the default public IP only for temporary testing.

---

## 📌 Bonus Quick-Fire Questions (For Practice)

| Question | Quick Answer |
|----------|-------------|
| How many subnets can a VPC have? | Up to 200 per VPC |
| Can a Security Group span VPCs? | No, SGs are VPC-specific |
| Default VPC — should you use it for production? | No, always create a custom VPC |
| What is the default CIDR of the default VPC? | 172.31.0.0/16 |
| Can two subnets have overlapping CIDRs? | No, they must be non-overlapping |
| What port does SSH use? | 22 |
| What is the default Nginx port? | 80 (HTTP), 443 (HTTPS) |
| Amazon Linux package manager? | `dnf` (or `yum` on Amazon Linux 2) |
| What is `chmod 400`? | Read-only for owner, nothing for others |
| Can a private subnet have a NAT Instance instead of NAT Gateway? | Yes, but NAT Instance is unmanaged and not recommended |

---

*Document: INTERVIEW-QUESTIONS.md | 30 Questions | Level: Fresher → 2 Years*
