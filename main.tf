# BACKEND S3
terraform {
  backend "s3" {
    bucket = "tf-state-aml"
    key    = "State-file-back/terraform.tfstate"
    region = "us-east-1"
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main_vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main_igw"
  }
}

# Subnets
resource "aws_subnet" "db_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name = "db_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet"
  }
}

# NAT Gateway and EIP
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "private_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.db_subnet.id
}

# Route Tables
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private_nat.id
  }

  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "db_subnet_association" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group for SSH
resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
  }
}

# IAM Role for the Jump Server
resource "aws_iam_role" "jump_server_role" {
  name = "jump_server_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "jump_server_role"
  }
}

# IAM Policy for SES actions
resource "aws_iam_policy" "ses_policy" {
  name        = "ses_policy"
  description = "IAM policy for SES actions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "ses_policy"
  }
}

# Attach SES Policy to the Jump Server Role
resource "aws_iam_role_policy_attachment" "ses_role_attachment" {
  role       = aws_iam_role.jump_server_role.name
  policy_arn = aws_iam_policy.ses_policy.arn
}

# SES Email and Domain Identity
resource "aws_ses_email_identity" "verified_email" {
  email = var.ses_email
}

resource "aws_ses_domain_identity" "verified_domain" {
  domain = var.ses_domain
}

# Create Route 53 Hosted Zone
resource "aws_route53_zone" "devopsrangers_zone" {
  name    = var.ses_domain
  comment = "Hosted zone for ${var.ses_domain}"

  tags = {
    Name = "${var.ses_domain} hosted zone"
  }
}

# Route 53 Record for SES Domain Verification
resource "aws_route53_record" "ses_verification_record" {
  zone_id = aws_route53_zone.devopsrangers_zone.zone_id
  name    = aws_ses_domain_identity.verified_domain.domain
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.verified_domain.verification_token]
}

# EC2 Instances
resource "aws_instance" "etl_server" {
  ami             = var.ami
  instance_type   = "t2.medium"
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "etl_server"
  }
}

resource "aws_instance" "jump_server" {
  ami             = var.ami
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "jump_server"
  }
}

# RDS Postgres Database Cluster
resource "aws_rds_cluster" "rds_postgres_cluster" {
  cluster_identifier      = var.rds_cluster_identifier
  engine                  = "aurora-postgresql"
  engine_version          = "13.6"
  master_username         = var.db_username
  master_password         = var.db_password
  database_name           = var.db_name
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  vpc_security_group_ids  = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "postgres-db-cluster"
  }
}

# RDS Postgres Database Instances
resource "aws_rds_cluster_instance" "rds_postgres_instance" {
  identifier               = "database-1-instance"
  cluster_identifier       = aws_rds_cluster.rds_postgres_cluster.id
  instance_class           = "db.t4g.micro"
  publicly_accessible      = false
  engine                   = aws_rds_cluster.rds_postgres_cluster.engine
  engine_version           = aws_rds_cluster.rds_postgres_cluster.engine_version
  auto_minor_version_upgrade = true
  db_subnet_group_name     = aws_db_subnet_group.main.id

  tags = {
    Name = "postgres-db-instance"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.db_subnet.id, aws_subnet.private_subnet.id]

  tags = {
    Name = "main_db_subnet_group"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.s3_bucket_name
  tags = {
    Name = "my_etl_bucket"
  }
}

# Secrets Manager for DB credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "rds-db-credentials-new5"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "etl_logs" {
  name              = "/aws/etl/logs"
  retention_in_days = 30
}
