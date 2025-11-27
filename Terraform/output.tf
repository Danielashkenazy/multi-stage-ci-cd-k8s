
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_oidc_issuer_url" {
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "jenkins_public_ip" {
  value       = module.compute.jenkins_public_ip
  description = "Jenkins public IP address"
}

output "jenkins_public_url" {
  value       = "http://${module.compute.jenkins_public_ip}:8080"
  description = "Jenkins web UI URL"
}


output "slave_private_ip" {
  value       = module.compute.slave_private_ip
  description = "slave instance private IP address"
}

output "ssh_command_jenkins" {
  value       = "ssh -i jenkins-shared-key.pem ubuntu@${module.compute.jenkins_public_ip}"
  description = "SSH command for Jenkins instance"
}

output "scp_command_app" {
  value       = "scp -i jenkins-shared-key.pem ./jenkins-shared-key.pem ubuntu@${module.compute.jenkins_public_ip}:/home/ubuntu/jenkins-shared-key.pem "
  description = "SSH command for slave instance (via Jenkins bastion)"
}

output "jenkins_credentials" {
  value = {
    username = "admin"
    password = "Admin123!"
    agent    = "app-agent"
  }
  description = "Jenkins login credentials"
  sensitive   = true
}
output "jenkins_sa_token" {
  value     = kubernetes_secret.jenkins_sa_token.data["token"]
  sensitive = true
}

output "jenkins_sa_ca" {
  value     = kubernetes_secret.jenkins_sa_token.data["ca.crt"]
  sensitive = true
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

###temporary outputs for debugging###
output "debug_cluster_endpoint" {
  value = try(data.aws_eks_cluster.this.endpoint, "NOT FOUND")
}

output "debug_cluster_name" {
  value = try(module.eks.cluster_name, "NOT FOUND")
}

output "debug_cluster_exists" {
  value = try(data.aws_eks_cluster.this.id, "NOT FOUND")
}
