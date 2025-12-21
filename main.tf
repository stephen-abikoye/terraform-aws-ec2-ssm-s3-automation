# Provision a VPC + EC2 + S3 + IAM role using Terraform.

# IAM role for EC2 to access S3
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy attachment to allow S3 access
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_s3_access_policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.bucket1.arn,
          "${aws_s3_bucket.bucket1.arn}/*"
        ]

      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore policy for SSM access
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "node1" {
  ami                    = "ami-068c0051b15cdb816"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = aws_subnet.subnet1.id

  user_data = <<-EOF
#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data ) 2>&1
set -x

echo "Cloud-init started"

dnf install -y awscli python3 python3-boto3

cat <<'PYTHON' > /opt/s3_app.py
import boto3
import datetime
import time

bucket_name = "${aws_s3_bucket.bucket1.bucket}"
s3 = boto3.client("s3")

for i in range(10):
    try:
        content = f"Hello from EC2 via IAM role at {datetime.datetime.utcnow()}"
        s3.put_object(
            Bucket=bucket_name,
            Key="hello-from-ec2.txt",
            Body=content
        )
        print("Upload successful")
        break
    except Exception as e:
        print(f"Retry {i+1}/10 failed: {e}")
        time.sleep(10)
PYTHON

python3 /opt/s3_app.py

echo "Cloud-init finished"
EOF

  depends_on = [
    aws_s3_bucket.bucket1,
    aws_iam_role_policy.ec2_policy,
    aws_iam_role_policy_attachment.ssm_core
  ]

}

# VPC and Networking Resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create a Subnet
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create a Route Table
resource "aws_route_table" "routetable1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.routetable1.id
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name   = "ec2_sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 Bucket with Ownership Controls and ACL
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "bucket1" {
  bucket = "my-unique-bucket-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucket1.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.example]

  bucket = aws_s3_bucket.bucket1.id
  acl    = "private"
}

