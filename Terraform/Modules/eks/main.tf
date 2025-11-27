module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.30"

  vpc_id     = var.vpc_id
  subnet_ids = [var.public_subnet_a_id, var.public_subnet_b_id, var.private_subnet_a_id]

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr

  enable_irsa = true

  eks_managed_node_groups = {
    public_nodes = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.micro"]
      subnet_ids     = [var.public_subnet_a_id, var.public_subnet_b_id]
    }
    private_nodes = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.micro"]
      subnet_ids     = [var.private_subnet_a_id]
    }
  }
  cluster_security_group_additional_rules = {
    allow_slave_to_eks_api = {
    description                   = "Allow Jenkins Slave to EKS API"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_security_group_id      = var.slave_sg_id
    }
  }
  tags = { Environment = "test" }
}




