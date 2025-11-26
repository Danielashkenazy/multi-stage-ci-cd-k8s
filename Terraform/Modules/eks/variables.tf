variable "vpc_id" {
  description = "vpc id for eks"
}
variable "public_subnet_a_id" {
  description = "public subnet a id for eks"
}
variable "public_subnet_b_id" {
  description = "public subnet b id for eks"
}
variable "private_subnet_a_id" {
  description = "private subnet a id for eks"
}
variable "allowed_cidr" {
  description = "allowed cidr for eks access"
}

