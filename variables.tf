# AWS Region
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

# SES email to verify
variable "ses_email" {
  description = "Email address to verify in SES"
  default     = "skrishnan586@gmail.com"
}

# SES domain to verify
variable "ses_domain" {
  description = "Domain to verify in SES"
  default     = "devopsrangers.online"
}

# VPC CIDR block
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

# Subnet CIDRs
variable "db_subnet_cidr" {
  description = "CIDR block for the database subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  default     = "10.0.2.0/24"
}

# AMI for EC2 instances
variable "ami" {
  description = "AMI ID for EC2 instances"
  default     = "ami-12345678"
}

# S3 Bucket Name
variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  default     = "my-etl-bucket"
}

# RDS Cluster Info
variable "rds_cluster_identifier" {
  description = "RDS cluster identifier"
  default     = "rds-postgres-cluster"
}

variable "db_name" {
  description = "Name of the database"
  default     = "mydb"
}

variable "db_username" {
  description = "Database username"
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database password"
  default     = "password123"
}
