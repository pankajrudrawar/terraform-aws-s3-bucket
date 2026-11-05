output "id" {
  description = "Name of the bucket"
  value       = try(aws_s3_bucket.this[0].id, null)
}

output "arn" {
  description = "ARN of the bucket"
  value       = try(aws_s3_bucket.this[0].arn, null)
}

output "bucket_domain_name" {
  description = "Bucket domain name, for example `bucket.s3.amazonaws.com`"
  value       = try(aws_s3_bucket.this[0].bucket_domain_name, null)
}

output "bucket_regional_domain_name" {
  description = "Region-specific bucket domain name"
  value       = try(aws_s3_bucket.this[0].bucket_regional_domain_name, null)
}

output "region" {
  description = "AWS region the bucket lives in"
  value       = try(aws_s3_bucket.this[0].region, null)
}
