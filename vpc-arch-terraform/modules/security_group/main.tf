# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP MODULE
#
# Key concept: Security Groups are STATEFUL.
# If you allow inbound SSH (22), the response is automatically allowed outbound.
# You never need a separate outbound rule for allowed inbound connections.
#
# Industry pattern: reference SG-to-SG (not IP-to-IP) for internal rules.
# private-ec2-sg allows SSH from bastion-sg ID — if Bastion is recreated with
# a new IP, the rule still works because it targets the SG, not the IP.
# ─────────────────────────────────────────────────────────────────────────────

# ── Bastion Host Security Group ───────────────────────────────────────────────
# Only YOUR IP can SSH in. Everything else is blocked.
# This is the "least privilege" principle — expose the minimum required.
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH only from admin IP - Bastion jump server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Outbound: allow all — Bastion needs to reach private EC2 and internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Role    = "Bastion"
    Project = var.project_name
  }
}

# ── Private EC2 Security Group ────────────────────────────────────────────────
# SSH: only from Bastion SG (not from internet — private subnet has no public IP anyway)
# HTTP: open for Nginx — referenced by SG ID so it survives Bastion IP changes
resource "aws_security_group" "private_ec2" {
  name        = "${var.project_name}-private-ec2-sg"
  description = "SSH from Bastion SG only; HTTP open for Nginx"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH via Bastion jump server only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id] # SG reference, not an IP
  }

  ingress {
    description = "HTTP for Nginx web server"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: allow all — needed so private EC2 can reach NAT for git/dnf
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-private-ec2-sg"
    Role    = "PrivateEC2"
    Project = var.project_name
  }
}
