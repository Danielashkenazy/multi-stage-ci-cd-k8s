output "jenkins_sa_token" {
    value     = kubernetes_secret.jenkins_sa_token.data["token"]
    sensitive = true
    }

output "jenkins_sa_ca" {
    value     = kubernetes_secret.jenkins_sa_token.data["ca.crt"]
    sensitive = true
    }
