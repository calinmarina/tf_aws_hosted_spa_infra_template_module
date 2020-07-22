variable "domain" {
  description = "Domain where SPA will be deployed"
}

variable "certificate_arn" {
  description = "ACM ARN for valid certificate on specified domain"
}

variable "env" {
  default = "production"
}