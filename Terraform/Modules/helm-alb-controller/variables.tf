variable "vpc_id" {
    description = "VPC ID where the ALB controller will be deployed"
}           
variable "cluster_name" {
    description = "EKS Cluster Name where the ALB controller will be deployed"
}
variable "alb_sa_name" {
    description = "Service Account Name for ALB Controller"
}
variable "alb_role_arn" {
    description = "IAM Role ARN for ALB Controller"
}

