output "s3_bucket" {
  value = aws_s3_bucket.domainBucket.bucket
}

output "spa_cloudfront" {
  value = {
    domain = aws_cloudfront_distribution.s3Distribution.domain_name
    arn    = aws_cloudfront_distribution.s3Distribution.arn
    status = aws_cloudfront_distribution.s3Distribution.status
  }
}