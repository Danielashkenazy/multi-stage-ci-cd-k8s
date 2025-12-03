
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow Jenkins access"
  vpc_id      = var.vpc_id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins_sg"
  }
}
resource "aws_security_group_rule" "jenkins_ssh_from_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.own_ip]
  security_group_id = aws_security_group.jenkins_sg.id
}
resource "aws_security_group_rule" "jenkins_ui_from_admin" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.own_ip]
  security_group_id = aws_security_group.jenkins_sg.id
}
resource "aws_security_group_rule" "jenkins_webhook_from_github" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.github_webhook_cidr
  security_group_id = aws_security_group.jenkins_sg.id
}

resource "aws_security_group" "slave_sg" {
  name        = "slave_sg"
  description = "Allow slave access"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "slave_sg"
  }
}
resource "aws_security_group_rule" "jenkins_allow_slave_ui" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_sg.id
  source_security_group_id = aws_security_group.slave_sg.id
  description              = "slave can access Jenkins web UI"
}
resource "aws_security_group_rule" "jenkins_allow_slave_jnlp" {
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_sg.id
  source_security_group_id = aws_security_group.slave_sg.id
  description              = "slave can connect to Jenkins JNLP port"
}
resource "aws_security_group_rule" "jenkins_allow_eks_jnlp" {
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_sg.id
  cidr_blocks              = ["${var.nat_eip}/32"]
  description              = "EKS nodes can connect to Jenkins JNLP port"
}
//resource "aws_security_group_rule" "slave_allow_ssh_from_jenkins" {
//  type                     = "ingress"
//  from_port                = 22
//  to_port                  = 22
//  protocol                 = "tcp"
//  security_group_id        = aws_security_group.slave_sg.id
//  source_security_group_id = aws_security_group.jenkins_sg.id
//  description              = "Jenkins can SSH into slave"
//}

######EKS Security Group Rules######
resource "aws_security_group_rule" "jenkins_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_sg_id   
  source_security_group_id = aws_security_group.jenkins_sg.id
  description              = "Jenkins SG can access EKS API"
}
resource "aws_security_group_rule" "slave_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_sg_id   
  source_security_group_id = aws_security_group.slave_sg.id
  description              = "Slave SG can access EKS API"
}
resource "aws_security_group_rule" "jenknis_to_eks_jnlp" {
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_sg.id
  source_security_group_id = var.eks_node_sg_id
  description              = "EKS Nodes can access Jenkins JNLP port"
}
resource "aws_security_group_rule" "eks_nodes_to_jenkins_jnlp" {
  type                     = "egress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  security_group_id        = var.eks_node_sg_id
  source_security_group_id = aws_security_group.jenkins_sg.id
  description              = "EKS Nodes can access Jenkins JNLP port"
}