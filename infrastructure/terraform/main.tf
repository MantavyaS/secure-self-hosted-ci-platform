provider "aws" {
  region = "us-east-1"
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "secure_ci_vpc"
  cidr = "10.0.0.0/16"

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets = ["10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false 
  map_public_ip_on_launch = true
  
  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
  }
}

resource "aws_security_group" "secure_ci_sg" {
  name = "secure-ci-sg"
  description = "security group for the secure self hosted CI platform"
  vpc_id = module.vpc.vpc_id

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
  }
}

resource "aws_security_group_rule" "ssh_ingress" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.secure_ci_sg.id
  cidr_blocks = ["142.189.201.143/32"]
}

resource "aws_security_group_rule" "all_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "tcp"
  security_group_id = aws_security_group.secure_ci_sg.id
  cidr_blocks = ["0.0.0.0/0"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "ci-platform-server" {
  ami = data.aws_ami.ubuntu.id

  instance_type = var.instance_type

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted = true
    delete_on_termination = true
  }

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
    Name        = var.instance_name
  }
}