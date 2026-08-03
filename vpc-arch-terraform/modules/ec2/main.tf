# ─────────────────────────────────────────────────────────────────────────────
# EC2 MODULE — Bastion Host (public) + Dev Server (private, runs Nginx)
#
# Key Terraform concept introduced here: DATA SOURCES
#   data "aws_ami" reads existing AWS information (does NOT create anything).
#   This gives you the latest Amazon Linux 2023 AMI ID dynamically — so your
#   code never has hardcoded AMI IDs that go stale across regions/time.
#
# Without a data source you would hardcode: ami = "ami-0abc123def456789"
# With a data source Terraform resolves it automatically every time.
# ─────────────────────────────────────────────────────────────────────────────

# ── Data Source: Latest Amazon Linux 2023 AMI ─────────────────────────────────
# Equivalent to: EC2 Console → AMI Catalog → Amazon Linux 2023 → copy AMI ID
# filters narrow down to exactly the AMI you want; most_recent picks the newest.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"] # Only trust AMIs published by AWS

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # x86_64 = standard Intel/AMD arch
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"] # HVM = hardware virtual machine (required for modern instance types)
  }
}

# ── Bastion Host (Jump Server) ────────────────────────────────────────────────
# Sits in the PUBLIC subnet.
# Its only job: be the single entry point for SSH into the private network.
# No application workload runs here — only SSH forwarding.
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true # MUST be true — Bastion needs a public IP

  tags = {
    Name    = "${var.project_name}-bastion-host"
    Role    = "Bastion"
    Project = var.project_name
  }
}

# ── Private Dev Server (Nginx) ────────────────────────────────────────────────
# Sits in the PRIVATE subnet — no public IP, only reachable via Bastion.
# user_data: a shell script that runs ONCE when the instance first boots.
# This is how you automate software installation without manually SSHing in.
resource "aws_instance" "dev_server" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.private_ec2_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = false # Private server — NO public IP

  # user_data bootstraps Nginx on first boot (replaces manual SSH + dnf install)
  user_data = <<-EOF
    #!/bin/bash
    set -e
    dnf update -y
    dnf install -y nginx git

    systemctl start nginx
    systemctl enable nginx

    # Deploy a simple page that proves Terraform provisioned this server
    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head><title>Week 2 — Terraform Deployed!</title></head>
    <body style="font-family:sans-serif;text-align:center;margin-top:80px;">
      <h1>&#x2705; VPC Architecture — Provisioned by Terraform</h1>
      <p>Private Dev Server | Nginx running | Week 2 complete</p>
      <p>Subnet: Private | Access: Via Bastion Host only</p>
    </body>
    </html>
    HTML

    chown -R nginx:nginx /usr/share/nginx/html/
    chmod -R 755 /usr/share/nginx/html/
    systemctl restart nginx
  EOF

  # dev_server depends on the VPC being fully ready.
  # Terraform usually infers this from the subnet_id reference,
  # but explicit depends_on makes the dependency visible for learning.
  tags = {
    Name    = "${var.project_name}-dev-server"
    Role    = "DevServer"
    Project = var.project_name
  }
}
