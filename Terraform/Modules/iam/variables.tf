variable "cluster_name" {
    description = "EKS Cluster Name"
}
         
variable "oidc_provider_arn" {
    description = "OIDC Provider ARN"
}

variable "oidc_issuer_url" {
    description = "OIDC Issuer URL"
}

variable "your_iam_role_arn" {
    description = "IAM Role Name for EKS Access"
}
variable "token_dependency_barrier" {
  type    = string
  default = ""
}