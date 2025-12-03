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
  jenkins_sg_id       = module.security.jenkins_sg_id
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
   providers = {
    kubernetes = kubernetes
  }

}
module "security" {
  source = "./Modules/security"
  vpc_id = module.vpc.vpc_id
  own_ip = var.own_ip
  github_webhook_cidr = var.github_webhook_cidr
  nat_eip = module.vpc.nat_eip
  eks_cluster_sg_id = module.eks.eks_cluster_sg_id
  eks_node_sg_id = module.eks.eks_node_sg_id
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
  
  depends_on = [module.iam, module.eks, module.vpc]
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

module "k8s_foundation" {
  source = "./modules/k8s_foundation"
  
  aws_eks_cluster_this_endpoint = data.aws_eks_cluster.this.endpoint
  aws_eks_cluster_auth_this_token = data.aws_eks_cluster_auth.this.token
  
  depends_on = [module.eks, data.aws_eks_cluster.this, data.aws_eks_cluster_auth.this, module.iam]
  
  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
}


module "monitoring" {
  source = "./modules/monitoring"
  
  depends_on = [module.eks, data.aws_eks_cluster.this, data.aws_eks_cluster_auth.this, module.iam]
  
  providers = {
    helm = helm
  }
}