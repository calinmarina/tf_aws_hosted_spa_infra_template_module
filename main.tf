locals {
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
  policy = templatefile("${path.module}/bucket-policy.tmpl", { oai_id = aws_cloudfront_origin_access_identity.originAccessIdentity.id, bucket_name = var.domain.name })

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

#Create static content bucket
resource "aws_s3_bucket" "staticContentBucket" {
  bucket = local.staticContentBucketName
  acl    = "bucket-owner-full-control"
  policy = templatefile("${path.module}/bucket-policy.tmpl", { oai_id = aws_cloudfront_origin_access_identity.originAccessIdentity.id, bucket_name = local.staticContentBucketName })

  # website {
  #   index_document = "index.html"
  # }

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

  origin {
    domain_name = aws_s3_bucket.staticContentBucket.bucket_regional_domain_name
    origin_id   = local.staticContentBucketName

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.originAccessIdentity.cloudfront_access_identity_path
    }
  }

  tags = local.common_tags

  aliases             = [var.domain.name, join(".", ["www", var.domain.name])]
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
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "static/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.staticContentBucketName

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
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

  # web_acl_id = aws_wafv2_ip_set.IPrestrictRule.arn
}

## Disable together with web_acl_id above to activate CloudFront WAFs
## IP filtering access 
# resource "aws_wafv2_ip_set" "IPrestrictRule" {
#   name               = "example"
#   description        = "Example IP set"
#   scope              = "CLOUDFRONT"
#   ip_address_version = "IPV4"
#   addresses          = [ <<IP list, maybe passed via input parameter>> ]

#   tags = local.common_tags
# }

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