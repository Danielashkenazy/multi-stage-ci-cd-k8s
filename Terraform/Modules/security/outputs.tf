output "jenkins_sg_id" {
  value       = aws_security_group.jenkins_sg.id
  description = "Security Group ID for Jenkins instance"
}
output "slave_sg_id" {
  value       = aws_security_group.slave_sg.id
  description = "Security Group ID for slave instance"
}
