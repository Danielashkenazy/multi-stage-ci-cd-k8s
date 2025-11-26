variable "vpc_id" {
  description = "id of the used VPC"
}
variable "own_ip" {
  description = "Your own IP address with CIDR notation"
}
variable "github_webhook_cidr" {
  description = "CIDR block for GitHub webhook access"
}
