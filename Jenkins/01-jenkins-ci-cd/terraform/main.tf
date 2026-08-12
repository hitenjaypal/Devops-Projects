# ==============================================================================
# Main Infrastructure Definition
# Project: 01-jenkins-ci-cd
# ==============================================================================

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

# Fetch VPC details (default VPC if var.vpc_id is not specified)
data "aws_vpc" "selected" {
  default = var.vpc_id == "" ? true : false
  id      = var.vpc_id != "" ? var.vpc_id : null
}

# Fetch Subnet details if var.subnet_id is not specified
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

# Security Group for Jenkins Server
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-server-sg-${var.environment}"
  description = "Security Group for Jenkins CI/CD Server"
  vpc_id      = data.aws_vpc.selected.id

  # SSH Access
  ingress {
    description = "Allow SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Jenkins Web UI Access
  ingress {
    description = "Allow Jenkins HTTP UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress Rule - Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-server-sg"
  }
}

# Security Group for Docker Host
resource "aws_security_group" "docker_host_sg" {
  name        = "docker-host-sg-${var.environment}"
  description = "Security Group for Docker Host Server"
  vpc_id      = data.aws_vpc.selected.id

  # SSH Access
  ingress {
    description = "Allow SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Node.js Web App Access
  ingress {
    description = "Allow Node App HTTP Traffic"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress Rule - Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker-host-sg"
  }
}

# ------------------------------------------------------------------------------
# EC2 Instances
# ------------------------------------------------------------------------------

# 1. Jenkins Server EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  key_name             = var.key_name != "" ? var.key_name : null
  subnet_id            = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.selected.ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = file("${path.module}/scripts/jenkins-setup.sh")

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "Jenkins-Server"
    Role = "Jenkins-Master"
  }
}

# 2. Docker Host EC2 Instance (Conditional)
resource "aws_instance" "docker_host" {
  count                = var.create_docker_host ? 1 : 0
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  key_name             = var.key_name != "" ? var.key_name : null
  subnet_id            = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.selected.ids[0]
  vpc_security_group_ids = [aws_security_group.docker_host_sg.id]

  user_data = file("${path.module}/scripts/docker-setup.sh")

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "Docker-Host"
    Role = "Application-Target"
  }
}
