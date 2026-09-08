#!/bin/bash
# ==============================================================================
# User Data Script: Jenkins Server Setup (Amazon Linux 2023)
# ==============================================================================

set -e

# Update System Packages
sudo dnf update -y

# Install Java 21 (Required for Jenkins 2.500+)
sudo dnf install java-21-amazon-corretto -y

# Install Git
sudo dnf install git -y

# Add Jenkins Repository & Import Key
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo dnf install jenkins -y

# Enable and Start Jenkins Service
sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Jenkins installation completed successfully."
