output "ec2_instance_id" {
  description = "EC2 instance ID (used for SSM Session Manager)"
  value       = aws_instance.node1.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used by the EC2 application"
  value       = aws_s3_bucket.bucket1.bucket
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}
