# terraform/modules/ebs-csi-driver/outputs.tf

output "storage_class_name" {
  description = "Name of the gp3 StorageClass"
  value       = kubernetes_storage_class_v1.gp3.metadata[0].name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.name
}

output "addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

output "addon_version" {
  description = "Version of the EBS CSI driver addon installed"
  value       = aws_eks_addon.ebs_csi_driver.addon_version
}

output "storage_class_default" {
  description = "Whether gp3 is set as the default StorageClass"
  value       = var.set_as_default
}
