# Kafenox Terraform Infrastructure

This directory contains the Terraform configuration for the Kafenox project infrastructure.

## Resources Created

- **S3 Bucket**: `kafenox-data` - Data storage bucket with versioning and encryption
- **ECR Repository**: `kafenox-agent` - Container registry for the Kafenox agent

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed (>= 1.0)
3. Terraform cloud project and workspace setup.

## Setup

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your AWS account ID and preferred settings.

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Plan the deployment:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Backend Configuration

The Terraform state is stored in an S3 bucket named `tf-states-<AWS_ACCOUNT_ID>`. Make sure this bucket exists before running `terraform init`.

## Security Features

- S3 bucket has versioning enabled
- S3 bucket uses server-side encryption
- S3 bucket blocks all public access
- ECR repository has image scanning enabled
- ECR repository has lifecycle policy to manage image retention