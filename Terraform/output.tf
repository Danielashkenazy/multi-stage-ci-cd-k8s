
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_oidc_issuer_url" {
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

