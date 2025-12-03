#### Namespace Creation ####

resource "kubernetes_namespace" "devops" {
  metadata {
    name = "devops"
  }

}


####Service account creation + Binding - For CD on Jenkins to EKS####
resource "kubernetes_service_account" "jenkins_deployer" {
  
  metadata {
    name      = "jenkins-deployer"
    namespace = "devops"
  }
}

resource "kubernetes_role" "jenkins_deployer_role" {
  

  metadata {
    name      = "jenkins-deployer-role"
    namespace = "devops"
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["pods", "services", "deployments","exec","pods/exec"]
    verbs      = ["create","get", "list", "watch", "create", "update", "patch","delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch","delete"]
  }
  rule {
  api_groups = ["networking.k8s.io"]
  resources  = ["ingresses"]
  verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
 }
 rule {
  api_groups = ["apps"]
  resources  = ["deployments","scale"]
  verbs      = ["get", "update", "patch"]
}


}

resource "kubernetes_role_binding" "jenkins_deployer_binding" {
  
  metadata {
    name      = "jenkins-deployer-binding"
    namespace = "devops"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_deployer_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins_deployer.metadata[0].name
    namespace = "devops"
  }
   depends_on = [
    kubernetes_service_account.jenkins_deployer,
    kubernetes_role.jenkins_deployer_role,
  ]
}


#### Service account Secret ####
resource "kubernetes_secret" "jenkins_sa_token" {
  

  metadata {
    name      = "jenkins-deployer-token"
    namespace = kubernetes_namespace.devops.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.jenkins_deployer.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.jenkins_deployer
  ]
}



#### Auto scaling setup ####


resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}
resource "kubernetes_horizontal_pod_autoscaler_v2" "app_hpa" {
  metadata {
    name      = "app-hpa"
    namespace = "devops"
  }

  spec {
    min_replicas = 2
    max_replicas = 10

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "python-app-rickandmorty"

    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy = "Max"
        policy {
          type          = "Percent"
          value         = 100
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 60
        select_policy = "Max"
        policy {
          type          = "Percent"
          value         = 50
          period_seconds = 60
        }
      }
    }
  }
}