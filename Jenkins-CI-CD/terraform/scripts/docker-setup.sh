#!/bin/bash
# ==============================================================================
# User Data Script: Docker Host Setup (Amazon Linux 2023)
# ==============================================================================

set -e

# Update System Packages
sudo dnf update -y

# Install Docker
sudo dnf install docker -y

# Enable and Start Docker Service
sudo systemctl enable docker
sudo systemctl start docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Create dockeradmin user for Jenkins Publish Over SSH integration
sudo useradd dockeradmin
echo "dockeradmin:dockeradmin" | sudo chpasswd
sudo usermod -aG docker dockeradmin

# Create deployment directory
sudo mkdir -p /opt/docker
sudo chown -R dockeradmin:dockeradmin /opt/docker
sudo chmod -R 775 /opt/docker

# Enable password authentication for SSH (Required for Publish Over SSH plugin)
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl reload sshd

echo "Docker Host setup completed successfully."
