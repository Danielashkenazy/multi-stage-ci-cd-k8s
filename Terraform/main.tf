provider "aws" {
  region = "us-west-2"
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.58.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  //backend "s3" {
  // bucket =  " " //Insert the name of the created bucket in here(from the ecr_s3 module output)
  //key    = "global/s3/terraform.state"
  //region = "us-west-2"
  //}
  // Uncomment the backend block above and provide the bucket name after the first run of terraform apply
}


data "aws_caller_identity" "current" {}


module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  private_subnet_a_cidr = var.private_subnet_a_cidr
}

module "eks" {
  source = "./modules/eks"
  allowed_cidr        = [var.allowed_cidr]
  vpc_id              = module.vpc.vpc_id
  public_subnet_a_id  = module.vpc.public_subnet_a_id
  public_subnet_b_id  = module.vpc.public_subnet_b_id
  private_subnet_a_id = module.vpc.private_subnet_a_id
  slave_sg_id         = module.security.slave_sg_id
  depends_on = [ module.vpc, module.compute ]


}


##Must be created after EKS is ready###
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token

}
provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
  
}



module "iam" {
  source = "./modules/iam"
  
  cluster_name          = module.eks.cluster_name
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_issuer_url       = module.eks.cluster_oidc_issuer_url
  your_iam_role_arn    = var.your_iam_role_arn
  depends_on = [ module.eks ]
  token_dependency_barrier = null_resource.kube_config_ready.id
   providers = {
    kubernetes = kubernetes
  }

}
module "security" {
  source = "./Modules/security"
  vpc_id = module.vpc.vpc_id
  own_ip = var.own_ip
  github_webhook_cidr = var.github_webhook_cidr
}


module "helm_alb_controller" {
  source = "./modules/helm-alb-controller"
  vpc_id           = module.vpc.vpc_id
  cluster_name     = module.eks.cluster_name
  alb_sa_name      = module.iam.lb_sa_name
  alb_role_arn     = module.iam.iam_role_alb_controller_arn
    providers = {
    helm = helm
  }
  
depends_on = [module.iam, module.eks, module.vpc, null_resource.kube_config_ready]
}


module "compute" {
  source = "./Modules/compute"
  instance_type = var.instance_type
  jenkins_sg_id = module.security.jenkins_sg_id
  slave_sg_id = module.security.slave_sg_id
  public_subnet_id = module.vpc.public_subnet_a_id
  private_subnet_id = module.vpc.private_subnet_a_id

  depends_on =  [ module.vpc ]
}

#####Creating a namespace for devops####
resource "kubernetes_namespace" "devops" {
  

  metadata {
    name = "devops"
  }

  depends_on = [
    module.eks,
    data.aws_eks_cluster.this,
    data.aws_eks_cluster_auth.this,
    null_resource.kube_config_ready
  ]
}

####Service account creation - For CD on Jenkins to EKS####
resource "kubernetes_service_account" "jenkins_deployer" {
  
  metadata {
    name      = "jenkins-deployer"
    namespace = "devops"
  }
  depends_on = [module.eks, data.aws_eks_cluster.this,data.aws_eks_cluster_auth.this, null_resource.kube_config_ready]
}

resource "kubernetes_role" "jenkins_deployer_role" {
  

  metadata {
    name      = "jenkins-deployer-role"
    namespace = "devops"
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["pods", "services", "deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch","delete"]
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
  depends_on = [module.eks, data.aws_eks_cluster.this,data.aws_eks_cluster_auth.this, null_resource.kube_config_ready]

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
    data.aws_eks_cluster_auth.this,
    null_resource.kube_config_ready
  ]
}
####Service account Secret ####
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


resource "null_resource" "kube_config_ready" {
  # המשאב הזה לא עושה כלום, רק מאלץ את הטעינה.
  triggers = {
    cluster_endpoint = data.aws_eks_cluster.this.endpoint
    cluster_token    = data.aws_eks_cluster_auth.this.token
  }
}