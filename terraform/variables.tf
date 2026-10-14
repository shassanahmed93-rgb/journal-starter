variable "aws_region" {
  description = "AWS region for the cluster, database, registry, and certificate."
  type        = string
}

variable "name" {
  description = "Short, lowercase application name used in AWS resource names."
  type        = string
  default     = "journal-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name must be 3-20 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Environment name used for tagging and resource names."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "Private IPv4 CIDR for the dedicated application VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones. Two are required for EKS and RDS subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "cluster_version" {
  description = "EKS Kubernetes version supported in the selected region."
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Explicit IPv4 CIDRs allowed to reach the public EKS API endpoint. Use stable egress IPs."
  type        = list(string)

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "Set cluster_endpoint_public_access_cidrs to the API clients' stable egress CIDRs."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired EKS worker count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum EKS worker count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum EKS worker count."
  type        = number
  default     = 4
}

variable "postgres_engine_version" {
  description = "Supported PostgreSQL 16.x engine version in the selected region."
  type        = string

  validation {
    condition     = can(regex("^16\\.", var.postgres_engine_version))
    error_message = "postgres_engine_version must be a supported PostgreSQL 16.x version."
  }
}

variable "postgres_instance_class" {
  description = "RDS PostgreSQL instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "postgres_multi_az" {
  description = "Enable RDS standby failover. Disable only for short-lived development environments."
  type        = bool
  default     = true
}

variable "postgres_storage_gib" {
  description = "Initial encrypted RDS storage in GiB."
  type        = number
  default     = 20
}

variable "postgres_max_storage_gib" {
  description = "Maximum RDS autoscaled storage in GiB."
  type        = number
  default     = 100
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, in owner/repository form."
  type        = string
  default     = "shassanahmed93-rgb/journal-starter"
}



variable "create_cloudfront" {
  description = "Create the public HTTPS CloudFront distribution after the Kubernetes ALB exists."
  type        = bool
  default     = false
}

variable "cloudfront_origin_domain_name" {
  description = "DNS hostname of the Kubernetes-created ALB. Required only when create_cloudfront is true."
  type        = string
  default     = ""

  validation {
    condition = (
      !var.create_cloudfront ||
      can(regex("^[a-z0-9.-]+\\.elb\\.amazonaws\\.com$", var.cloudfront_origin_domain_name))
    )
    error_message = "When CloudFront is enabled, set cloudfront_origin_domain_name to the ALB DNS hostname."
  }
}

variable "openai_base_url" {
  description = "OpenAI Responses API-compatible base URL injected into the application namespace."
  type        = string
  default     = "https://api.openai.com/v1"
}

variable "openai_model" {
  description = "Provider model or deployment name."
  type        = string
}

variable "alarm_notification_email" {
  description = "Email address that will receive the 5xx alarm; confirm the SNS subscription."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.alarm_notification_email))
    error_message = "alarm_notification_email must be a valid email address."
  }
}
