locals {
  subdomain               = join(".", ["www", var.domain.name])
  staticContentBucketName = join("-", [var.domain.name, "static"])
  common_tags = {
    project = var.domain.name
    env     = var.env
  }
  s3_origin_id = "myS3Origin"
}

#Create domain bucket
resource "aws_s3_bucket" "domainBucket" {
  bucket = var.domain.name
  acl    = "bucket-owner-full-control"
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.originAccessIdentity.id}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.domain.name}/*"
        }
    ]
}
EOF

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = local.common_tags
}

# resource "null_resource" "upload_files" {
#   depends_on = [aws_s3_bucket.domainBucket]
#   provisioner "local-exec" {
#       command = "bash -e aws s3 sync build/ s3://${var.domain.name}"
#       environment = {
#         "AWS_SHARED_CREDENTIALS_FILE"= "~/.aws/credentials"
#         "AWS_PROFILE"= "marinaconsult"
#       }
#     }
# }

# Create subdomain bucket
# www.<<mydomain>>
resource "aws_s3_bucket" "subdomainBucket" {
  bucket = local.subdomain
  acl    = "private"
  website {
    redirect_all_requests_to = aws_s3_bucket.domainBucket.website_endpoint
  }

  tags = local.common_tags
}

#Create static content bucket
resource "aws_s3_bucket" "staticContentBucket" {
  bucket = local.staticContentBucketName
  acl    = "private"

  tags = local.common_tags
}

resource "aws_cloudfront_origin_access_identity" "originAccessIdentity" {
  comment = "Cloud Front Origin Access Identity"
}

resource "aws_cloudfront_distribution" "s3Distribution" {
  origin {
    domain_name = aws_s3_bucket.domainBucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.originAccessIdentity.cloudfront_access_identity_path
    }
  }

  tags = local.common_tags

  aliases             = [var.domain.name, local.subdomain]
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  enabled             = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    compress               = true
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "domain_record" {
  depends_on = [aws_cloudfront_distribution.s3Distribution]
  zone_id    = var.domain.zone_id
  name       = ""
  type       = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3Distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3Distribution.hosted_zone_id
    evaluate_target_health = false
  }
}