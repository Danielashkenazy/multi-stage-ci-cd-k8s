terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
      configuration_aliases = [kubernetes]
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  oidc_provider_hostpath = replace(var.oidc_issuer_url, "https://", "")
}


####Iam role for alb controller###
resource "aws_iam_role" "alb_controller" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "${var.oidc_provider_arn}"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_provider_hostpath}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}
####Iam role for eks admin access####

resource "aws_iam_role" "eks_admin" {
  name = "EKSAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = "${var.your_iam_role_arn}"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

####Policy attachment for alb controller###

resource "aws_iam_policy_attachment" "alb_controller_attach" {
  name       = "AWSLoadBalancerControllerIAMPolicyAttach"
  roles      = [aws_iam_role.alb_controller.name]
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
}


####eks access entries and policies for selected role and iam role###
resource "aws_eks_access_entry" "your_role" {
  cluster_name  = var.cluster_name
  principal_arn = var.your_iam_role_arn
}

resource "aws_eks_access_policy_association" "your_role" {
  cluster_name  = var.cluster_name
  principal_arn = var.your_iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

####Kubernetes service account for alb controller###
resource "kubernetes_service_account" "alb_sa" {
    metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

}


