variable "instance_type" {
  description = "selected instance type for the comptue instances"
}
variable "jenkins_sg_id" {
  description = "Security Group ID for Jenkins instance"
}

variable "public_subnet_id" {
  description = "Public Subnet ID for Jenkins instance"
}
variable "private_subnet_id" {
  description = "Private Subnet ID for App instance"
}
variable "slave_sg_id" {
  description = "Security Group ID for slave instance"
}






