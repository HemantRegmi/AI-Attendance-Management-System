provider "aws" {
  region = "ap-south-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-security-group"
  description = "Allow inbound traffic for Jenkins and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SonarQube"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "${path.module}/myKey.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0400"
}

# --- Jenkins Server (Existing) ---
resource "aws_instance" "jenkins_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  key_name        = aws_key_pair.kp.key_name
  security_groups = [aws_security_group.jenkins_sg.name]

  user_data = file("${path.module}/install_jenkins.sh")

  tags = {
    Name = "Jenkins-Server"
  }
}

# --- K8s & Sonar Server (New) ---
resource "aws_instance" "k8s_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro" # Free Tier (with Swap)
  key_name        = aws_key_pair.kp.key_name
  security_groups = [aws_security_group.jenkins_sg.name]

  root_block_device {
    volume_size = 20 # Increase to 20GB (8GB default is too small for Swap+Sonar+K8s)
    volume_type = "gp3"
  }

  user_data = file("${path.module}/install_k8s_sonar.sh")

  tags = {
    Name = "K8s-Sonar-Server"
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "sonarqube_url" {
  value = "http://${aws_instance.k8s_server.public_ip}:9000"
}

output "ssh_jenkins" {
  value = "ssh -i myKey.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
}

output "ssh_k8s" {
  value = "ssh -i myKey.pem ubuntu@${aws_instance.k8s_server.public_ip}"
}
