variable "aws_region" {
  description = "Region where the Terraform state bucket will be created."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique bucket name for encrypted, versioned Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid 3-63 character S3 bucket name."
  }
}
