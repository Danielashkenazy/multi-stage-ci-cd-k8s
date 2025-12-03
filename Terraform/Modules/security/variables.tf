variable "vpc_id" {
  description = "id of the used VPC"
}
variable "own_ip" {
  description = "Your own IP address with CIDR notation"
}
variable "github_webhook_cidr" {
  description = "CIDR block for GitHub webhook access"
}
variable "nat_eip" {
    description = "Elastic IP for NAT gateway"
}
variable "eks_cluster_sg_id" {
  type = string
}
variable "eks_node_sg_id" {
  type = string
}