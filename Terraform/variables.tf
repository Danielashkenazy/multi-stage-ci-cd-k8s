variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR blocvk for the public subnet a"
    type        = string
    default     = "10.0.1.0/24"
}
variable "public_subnet_b_cidr" {
  description = "CIDR block for the public subnet b"
    type        = string
    default     = "10.0.2.0/24"
}
variable "private_subnet_a_cidr" {
  description = "CIDR block for the private subnet a"
    type        = string
    default     = "10.0.3.0/24"
}
variable "your_iam_role_arn" {
  description = "the iam role arn for kubernetes management"
}
variable "unique_bucket" {
  description = "The name of the bucket that will be used to store the Terraform backend state"
  default = "terraform-state-bucket-unique-name-054054"
}
variable "allowed_cidr" {
  description = "allowed cidr for eks access"
  default = "5.29.14.43/32"
}
variable "instance_type" {
  description = "Type of AWS EC2 instance"
  default     = "t3.small"
}
variable "own_ip" {
  description = "your own ip for allowing jenkins access"
  default = "5.29.14.43/32"
}
variable "github_webhook_cidr" {
  description = "github webhook cidr for allowing webhook calls"
  type = list(string)
  default = [
  "185.199.108.0/22",
  "140.82.112.0/20",
  "192.30.252.0/22",
  "143.55.64.0/20",
  "20.201.28.148/32",
  "20.205.243.166/32",
  "20.87.245.6/32",
  "20.175.192.149/32",
  "20.199.39.232/32",
  "20.27.173.85/32",
  "4.237.22.34/32",
  "4.225.11.201/32",
  "4.208.26.200/32",
  "0.0.0.0/0"]
}