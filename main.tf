locals {
  create_bucket = var.create
  attach_policy = var.create && (var.attach_deny_insecure_transport_policy || var.policy != null)
}

################################################################################
# Bucket
################################################################################

resource "aws_s3_bucket" "this" {
  count = local.create_bucket ? 1 : 0

  bucket              = var.bucket
  bucket_prefix       = var.bucket_prefix
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_versioning" "this" {
  count = local.create_bucket && var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    bucket_key_enabled = var.sse_algorithm == "AES256" ? null : var.bucket_key_enabled

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "AES256" ? null : var.kms_master_key_id
    }
  }
}

resource "aws_s3_bucket_logging" "this" {
  count = local.create_bucket && var.logging != null ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  target_bucket = var.logging.target_bucket
  target_prefix = var.logging.target_prefix
}

################################################################################
# Lifecycle
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = local.create_bucket && length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  # Lifecycle rules need versioning settled first when noncurrent rules are used
  depends_on = [aws_s3_bucket_versioning.this]

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.key
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []

        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []

        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [rule.value.abort_incomplete_multipart_upload_days] : []

        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }
}

################################################################################
# Bucket policy
################################################################################

data "aws_iam_policy_document" "this" {
  count = local.attach_policy ? 1 : 0

  source_policy_documents = var.policy != null ? [var.policy] : []

  dynamic "statement" {
    for_each = var.attach_deny_insecure_transport_policy ? [1] : []

    content {
      sid     = "DenyInsecureTransport"
      effect  = "Deny"
      actions = ["s3:*"]

      resources = [
        aws_s3_bucket.this[0].arn,
        "${aws_s3_bucket.this[0].arn}/*",
      ]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = local.attach_policy ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = data.aws_iam_policy_document.this[0].json

  # Apply the public access block first so a permissive policy cannot be rejected mid-apply
  depends_on = [aws_s3_bucket_public_access_block.this]
}
