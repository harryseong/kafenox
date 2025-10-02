resource "aws_s3_bucket" "kafenox_data" {
  bucket = "kafenox-data"
}

resource "aws_s3_bucket_versioning" "kafenox_data_versioning" {
  bucket = aws_s3_bucket.kafenox_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kafenox_data_encryption" {
  bucket = aws_s3_bucket.kafenox_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kafenox_data_pab" {
  bucket = aws_s3_bucket.kafenox_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
