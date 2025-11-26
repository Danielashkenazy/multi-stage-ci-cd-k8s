terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
  }
  kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "kubectl_manifest" "alb_crds" {
  yaml_body = data.http.alb_crds.response_body
  depends_on = [ data.http.alb_crds ]
}

data "http" "alb_crds" {
  url = "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
}
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.14.1"

  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.alb_sa_name
    },
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = "us-west-2"
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "defaultIngressClass"
      value = "true"
    }
  ]
    depends_on = [
    kubectl_manifest.alb_crds
  ]

}