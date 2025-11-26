
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
resource "aws_security_group_rule" "slave_allow_ssh_from_jenkins" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.slave_sg.id
  source_security_group_id = aws_security_group.jenkins_sg.id
  description              = "Jenkins can SSH into slave"
}
