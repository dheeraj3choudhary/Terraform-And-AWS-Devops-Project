# S3 Bucket for Source Data
resource "aws_s3_bucket" "tutorial-source-data-bucket" {
  bucket        = "tutorial-source-data-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_object" "data-object" {
  bucket = aws_s3_bucket.tutorial-source-data-bucket.bucket
  key    = "organizations.csv"
  source = "D:/Terraform_Tutorial/glue_job_S3_read_write/data_file/organizations.csv"
}

# S3 Bucket for Traget 
resource "aws_s3_bucket" "tutorial-target-data-bucket" {
  bucket        = "tutorial-target-data-bucket"
  force_destroy = true
}


# S3 Bucket for saving code
resource "aws_s3_bucket" "tutorial-code-bucket" {
  bucket        = "tutorial-code-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_object" "code-data-object" {
  bucket = aws_s3_bucket.tutorial-code-bucket.bucket
  key    = "script.py"
  source = "D:/Terraform_Tutorial/glue_job_S3_read_write/data_file/script.py"
}
