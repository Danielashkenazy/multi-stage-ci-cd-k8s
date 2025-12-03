output "cluster_name" {
  value = module.eks.cluster_name
}
output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_cluster_sg_id"{
  value = module.eks.cluster_security_group_id
}
output "eks_node_sg_id"{
  value = module.eks.node_security_group_id
}