# KMS Module - Key Management for Vault Auto-Unseal

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Vault-GitOps"
    }
  )
}

# KMS Key for Vault Auto-Unseal
resource "aws_kms_key" "vault" {
  description             = var.key_description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.common_tags,
    {
      Name    = var.key_name
      Purpose = "Vault Auto-Unseal"
    }
  )
}

# KMS Key Alias
resource "aws_kms_alias" "vault" {
  name          = "alias/${var.key_name}"
  target_key_id = aws_kms_key.vault.key_id
}

# IAM Role for Vault Service Account (IRSA)
resource "aws_iam_role" "vault_kms" {
  name = "${var.key_name}-vault-kms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.vault_namespace}:${var.vault_service_account}"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for KMS Access
resource "aws_iam_policy" "vault_kms" {
  name        = "${var.key_name}-vault-kms-policy"
  description = "Policy for Vault to use KMS for auto-unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault.arn
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "vault_kms" {
  role       = aws_iam_role.vault_kms.name
  policy_arn = aws_iam_policy.vault_kms.arn
}

# CloudWatch Log Group for KMS Key Usage
resource "aws_cloudwatch_log_group" "kms_audit" {
  name              = "/aws/kms/${var.key_name}"
  retention_in_days = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.key_name}-audit-logs"
    }
  )
}
