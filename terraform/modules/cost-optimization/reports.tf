
# Create S3 bucket for CUR
resource "aws_s3_bucket" "cur" {
  bucket = "${var.project_name}-cost-and-usage-report-${random_string.suffix.result}"
  tags   = var.tags
}


# Allow AWS CUR service to write to bucket
resource "aws_s3_bucket_policy" "cur" {
  bucket = aws_s3_bucket.cur.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAWSBillingToWrite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cur.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cur:${var.region}:${var.account_id}:report/${var.project_name}-cur"
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid       = "AllowAWSBillingToReadBucketPolicy"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = aws_s3_bucket.cur.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cur:${var.region}:${var.account_id}:report/${var.project_name}-cur"
            "aws:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}





resource "aws_s3_bucket_public_access_block" "cur" {
  bucket                  = aws_s3_bucket.cur.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# # Enable Cost & Usage Report
# resource "aws_cur_report_definition" "main" {
#   report_name               = "${var.project_name}-cur"  # ← CHANGED FROM 'name' TO 'report_name'
#   additional_schema_elements = ["RESOURCES"]
#   compression               = "GZIP"
#   format                    = "textORcsv"
#   report_versioning         = "CREATE_NEW_REPORT"
#   s3_bucket                 = aws_s3_bucket.cur.id
#   s3_prefix                 = "cur"
#   s3_region                 = var.region
#   time_unit                 = "HOURLY"

#   depends_on = [
#     aws_s3_bucket_public_access_block.cur,
#     aws_s3_bucket_policy.cur
#     ]

# }

# # Athena Integration
# output "cur_s3_path" {
#   value       = "s3://${aws_s3_bucket.cur.bucket}/cur/"
#   description = "Path to CUR data for Athena integration"
# }