locals {
  subdomain = join(".", ["www", var.domain])
  common_tags = {
    project = var.domain
    env     = var.env
  }
}

# Reuse existing zone to avoid allocation of different name servers after rebuild
# while domain name is still in process of migration from GoDaddy to AWS
data "aws_route53_zone" "route_zone" {
  name = var.domain
  tags = local.common_tags
}

#Create domain bucket
resource "aws_s3_bucket" "domainBucket" {
  bucket = var.domain
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.domain}/*"
            ]
        }
    ]
}
EOF

  tags = local.common_tags
}

# Create subdomain bucket
# www.<<mydomain>>
resource "aws_s3_bucket" "subdomainBucket" {
  bucket = local.subdomain
  website {
    redirect_all_requests_to = aws_s3_bucket.domainBucket.website_endpoint
  }
  tags = local.common_tags
}


resource "aws_cloudfront_distribution" "cloudFrontDistribution" {
  origin {
    domain_name = aws_s3_bucket.domainBucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.domainBucket.id
  }

  tags = local.common_tags

  aliases             = [var.domain, local.subdomain]
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  enabled             = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.domainBucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
  }
}

resource "aws_route53_record" "domain_record" {
  zone_id = data.aws_route53_zone.route_zone.zone_id
  name    = ""
  type    = "A"

  alias {
    name = aws_cloudfront_distribution.cloudFrontDistribution.domain_name
    zone_id = aws_cloudfront_distribution.cloudFrontDistribution.hosted_zone_id
    evaluate_target_health = false
  }
}