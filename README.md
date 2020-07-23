TF module to build infrastructure setup of a React SPA
===========

Opinionated template Terraform module to spin up infrastructure for a Single Page Application hosted on AWS S3 buckets

Module Input Variables
----------------------

- `domain` - Route 53 hosted zone domain object containing name and zone_id
- `certificate_arn` - AWS ACM certificate ARN
- `environment` - Defaults to production. Intended for CI/CD usage if testing or blue/green deployment environments needed

Usage
-----

```hcl
module "aws_s3_hosted_spa_infra_template" "mySpaInfra" {
  source          = "git::git@github.com:calinmarina/tf_aws_hosted_spa_infra_template_module.git"
  domain          = {
                      "name": data.aws_route53_zone.name,
                      "zone_id": data.aws_route53_zone.route_zone.zone_id
                    }
  certificate_arn = data.aws_acm_certificate.cert.arn
}

data "aws_route53_zone" "route_zone" {
  name =      "exampledomain.com"
}

data "aws_acm_certificate" "cert" {
  domain_name = "exampledomain.com"
  statuses    = ["ISSUED"]
}

```

Outputs
=======

 - `s3_bucket` - S3 Bucket Name
 - `spa_cloudfront` - CloudFront details to access the website

