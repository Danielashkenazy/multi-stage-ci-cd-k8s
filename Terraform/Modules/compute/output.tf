output "jenkins_public_ip" {
  value       = aws_instance.jenkins_instance.public_ip
  description = "Jenkins EC2 instance public IP"
}
output "slave_private_ip" {
  value       = aws_instance.slave_instance.private_ip
  description = "Slave EC2 instance private IP"
}
