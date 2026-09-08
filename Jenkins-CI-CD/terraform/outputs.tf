# ==============================================================================
# Infrastructure Outputs
# Project: 01-jenkins-ci-cd
# ==============================================================================

output "jenkins_public_ip" {
  description = "Public IP address of the Jenkins Server"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_private_ip" {
  description = "Private IP address of the Jenkins Server"
  value       = aws_instance.jenkins_server.private_ip
}

output "jenkins_url" {
  description = "Web URL to access Jenkins Dashboard"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins Server"
  value       = var.key_name != "" ? "ssh -i <path-to-${var.key_name}.pem> ec2-user@${aws_instance.jenkins_server.public_ip}" : "ssh ec2-user@${aws_instance.jenkins_server.public_ip}"
}

output "docker_host_public_ip" {
  description = "Public IP address of the Docker Host"
  value       = var.create_docker_host ? aws_instance.docker_host[0].public_ip : "N/A (create_docker_host = false)"
}

output "docker_host_private_ip" {
  description = "Private IP address of the Docker Host"
  value       = var.create_docker_host ? aws_instance.docker_host[0].private_ip : "N/A (create_docker_host = false)"
}

output "app_url" {
  description = "Web URL to access deployed Node.js App"
  value       = var.create_docker_host ? "http://${aws_instance.docker_host[0].public_ip}:3000" : "N/A (create_docker_host = false)"
}

output "docker_host_ssh_command" {
  description = "SSH command to connect to Docker Host"
  value       = var.create_docker_host ? (var.key_name != "" ? "ssh -i <path-to-${var.key_name}.pem> ec2-user@${aws_instance.docker_host[0].public_ip}" : "ssh ec2-user@${aws_instance.docker_host[0].public_ip}") : "N/A"
}
