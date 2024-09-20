# Output the VPC ID
output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

# Output the SES Domain Verification Status
output "ses_domain_verification_status" {
  value = aws_ses_domain_identity.verified_domain.verification_status
}

# Output the S3 Bucket Name
output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket.bucket
}

# Output the RDS Endpoint
output "rds_endpoint" {
  value = aws_rds_cluster.rds_postgres_cluster.endpoint
}
