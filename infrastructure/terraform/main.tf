provider "aws" {
  region = "us-east-1"
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "secure_ci_vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  enable_nat_gateway      = false
  single_nat_gateway      = false
  map_public_ip_on_launch = true

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
  }
}

resource "aws_security_group" "secure_ci_sg" {
  name        = "secure-ci-sg"
  description = "security group for the secure self hosted CI platform"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
  }
}

resource "aws_security_group_rule" "ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.secure_ci_sg.id
  cidr_blocks       = ["142.181.123.129/32"]
}

resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.secure_ci_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_key_pair" "secure_ci" {
  key_name = "secure_ci_key"

  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_instance" "ci_platform_server" {
  ami = data.aws_ami.ubuntu.id

  instance_type = var.instance_type

  iam_instance_profile = aws_iam_instance_profile.secure_ci_instance_profile.name

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.secure_ci_sg.id
  ]

  subnet_id = module.vpc.public_subnets[0]

  key_name = aws_key_pair.secure_ci.key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = file("${path.module}/scripts/bootstrap.sh")

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
    Name        = var.instance_name
  }
}


// IAM role

resource "aws_iam_role" "secure_ci_ec2_role" {
  name = "secure_ci_ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Project     = "Secure_Self_Hosted_CI_Platform"
    Environment = "dev"
    Owner       = "Mantavya"
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy" "secure_ci_container_policy" {
  name = "secure_ci_container_registry_read_policy"
  role = aws_iam_role.secure_ci_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "arc_secretes_access" {
  name = "arc-secrets-access"
  role = aws_iam_role.secure_ci_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.github_arc_private_key.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "secure_ci_instance_profile" {
  name = "secure_ci_instance_profile"
  role = aws_iam_role.secure_ci_ec2_role.name
}

// Creating an ECR instance

resource "aws_ecr_repository" "secure_ci_ecr" {
  name                 = "secure-ci-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "secure_ci_ecr" {
  repository = aws_ecr_repository.secure_ci_ecr.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

// secrets manager

resource "aws_secretsmanager_secret" "github_arc_private_key" {
  name = "github-arc-private-key"
  description = "contents of .pem file that was generated when installing the github app"
}

resource "aws_secretsmanager_secret_version" "github_arc_private_key_value" {
  secret_id = aws_secretsmanager_secret.github_arc_private_key.id
  secret_string = var.github_app_private_key
}