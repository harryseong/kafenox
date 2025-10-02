output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.kafenox_data.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.kafenox_data.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.kafenox_agent.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.kafenox_agent.arn
}
