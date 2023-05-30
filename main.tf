terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.app_server-ami.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.app_server.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.app_server.id
  vpc_security_group_ids = [aws_route_table.app_server.id]
  #vpc_security_group_ids      = [aws_security_group.app_server.id, aws_security_group.sg_web.id]

  tags = {
    Name = "app_server"
    Department = "me bitch"
    Billable = true
  }
}

resource "aws_vpc" "app_server" {
  cidr_block           = var.addr_space
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "app_server-vpc"
  }
}

resource "aws_subnet" "app_server" {
  vpc_id     = aws_vpc.app_server.id
  cidr_block = var.addr_subnet
  tags = {
    Name = "app_server-subnet"
  }
  availability_zone = "us-west-2a"
}

/**
This should proc DRIFT DETECTION

resource "aws_security_group" "sg_web" {
  name        = "sg_web"
  description = "allow 8080"
  vpc_id = aws_vpc.app_server.id
}

resource "aws_security_group_rule" "sg_web" {
  type      = "ingress"
  to_port   = "8080"
  from_port = "8080"
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_web.id
}
*/

resource "aws_security_group" "app_server" {
  name   = "my-security-group"
  vpc_id = aws_vpc.app_server.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-security-group"
  }
}

resource "aws_internet_gateway" "app_server" {
  vpc_id = aws_vpc.app_server.id
  tags = {
    Name = "app_server-internet-gateway"
  }
}

resource "aws_route_table" "app_server" {
  vpc_id = aws_vpc.app_server.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_server.id
  }
}

resource "aws_route_table_association" "app_server" {
  subnet_id      = aws_subnet.app_server.id
  route_table_id = aws_route_table.app_server.id
}

data "aws_ami" "app_server-ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  #owners = ["self"]
}

resource "aws_eip" "app_server" {
  instance = aws_instance.app_server.id
  vpc      = true
}

resource "aws_eip_association" "app_server" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_server.id
}

resource "null_resource" "configure-app_server" {
  depends_on = [aws_eip_association.app_server]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "web/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.app_server.private_key_pem
      host        = aws_eip.app_server.public_ip
    }
  }

  provisioner "remote-exec" {

    inline = [
        "sudo apt -y update",
        "sleep 1",
        "sudo apt -y update",
        "sudo apt -y install apache2",
        "sudo systemctl start apache2",
        "sudo cp /home/ubuntu/app.js /var/www/html",
        "sudo cp /home/ubuntu/index.html /var/www/html",
        //"sudo chown -R ubuntu:ubuntu /var/www/html",
        //"chmod +x *.sh",
        //"./deploy_app.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.app_server.private_key_pem
      host        = aws_eip.app_server.public_ip
    }
  }
}

resource "tls_private_key" "app_server" {
  algorithm = "RSA"
}

locals {
  private_key_filename = "my-ssh-key.pem"
}

resource "aws_key_pair" "app_server" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.app_server.public_key_openssh
}