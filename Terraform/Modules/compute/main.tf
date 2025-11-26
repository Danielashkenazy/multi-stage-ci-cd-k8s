
####Shared SSH Key for debugging####
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_shared_key" {
  key_name   = "jenkins-shared-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.jenkins_key.private_key_pem
  filename        = "${path.module}/jenkins-shared-key.pem"
  file_permission = "0600"
}

####Ubuntu AMI####
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}



####Jenkins Instance####
resource "aws_instance" "jenkins_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.jenkins_sg_id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.jenkins_shared_key.key_name
  
  tags = {
    Name = "Jenkins_Instance"
  }
  
  user_data = file("${path.module}/jenkins_user_data.sh")
}


####slave EC2 Instance####
resource "aws_instance" "slave_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.slave_sg_id]
  associate_public_ip_address = false

  key_name                    = aws_key_pair.jenkins_shared_key.key_name
  
  tags = {
    Name = "slave_Instance"
    
  }
  
  
  # Pass Jenkins private IP to the script
  user_data = templatefile("${path.module}/slave_user_data.sh.tmpl", {
    jenkins_private_ip = aws_instance.jenkins_instance.private_ip
  })
}



