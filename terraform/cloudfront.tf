resource "aws_cloudfront_distribution" "api" {
  count = var.create_cloudfront ? 1 : 0

  enabled         = true
  comment         = "${local.name} API"
  is_ipv6_enabled = true
  price_class     = "PriceClass_200"

  origin {
    domain_name = var.cloudfront_origin_domain_name
    origin_id   = "${local.name}-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "${local.name}-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    # Never cache API responses, including authenticated GET requests.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # Forward authorization headers, query strings, cookies, and other viewer
    # headers, except Host which must match the ALB origin.
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  lifecycle {
    precondition {
      condition     = var.create_cloudfront ? length(var.cloudfront_origin_domain_name) > 0 : true
      error_message = "Set cloudfront_origin_domain_name before enabling CloudFront."
    }
  }
}
