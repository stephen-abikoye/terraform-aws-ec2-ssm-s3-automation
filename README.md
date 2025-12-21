# Terraform AWS EC2 SSM + S3 Automation

## Overview
This project provisions AWS infrastructure using Terraform and demonstrates secure, automated interaction between an EC2 instance and Amazon S3 using IAM roles and AWS Systems Manager (SSM).

The EC2 instance runs without SSH access and uses cloud-init to execute a Python application that writes an object to an S3 bucket using the AWS SDK (boto3).

This project focuses on:
- Infrastructure as Code (IaC)
- Secure access patterns (IAM roles, no credentials)
- Cloud-init automation
- Real-world debugging of Amazon Linux 2023 behavior

---

## Architecture
- **VPC** with public subnet and internet gateway
- **EC2 instance** (Amazon Linux 2023)
- **IAM Role + Instance Profile**
  - S3 access policy
  - AmazonSSMManagedInstanceCore
- **S3 bucket** with randomized name
- **AWS Systems Manager (SSM)** for access (no SSH)
- **Python (boto3)** app executed via cloud-init

---

## Key Features
- No hardcoded AWS credentials
- No SSH keys or open inbound ports
- EC2 accessed securely via SSM Session Manager
- Automated S3 interaction using IAM role
- Dynamic AMI lookup (no hardcoded AMI IDs)
- Cloud-init logging and retry logic

---

## Prerequisites
- AWS account
- Terraform >= 1.5
- AWS CLI configured locally
- Permissions to create EC2, IAM, S3, VPC resources

---

## Deployment

### 1. Clone the repository
```bash
git clone https://github.com/stephen-abikoye/terraform-aws-ec2-ssm-s3-automation.git
cd terraform-aws-ec2-ssm-s3-automation
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Deploy infrastructure
```bash
terraform apply
```
Confirm with yes when prompted.

## Verification
### Check EC2 access via SSM
```bash
aws ssm start-session --target <instance-id>
```

### Verify cloud-init execution
```bash
cat /var/log/user-data.log
```

### Verify S3 object creation
```bash
aws s3 ls s3://<bucket-name>/
```
You should see:
hello-from-ec2.txt
