terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

module "s3_bucket" {
  source = "../.."

  bucket_prefix = "example-secure-bucket-"

  versioning_enabled = true
  sse_algorithm      = "AES256"

  lifecycle_rules = {
    archive-old-data = {
      prefix = "archive/"
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
      noncurrent_version_expiration_days = 180
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "bucket_name" {
  value = module.s3_bucket.id
}
