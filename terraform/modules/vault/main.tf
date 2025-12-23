# Vault Module - HashiCorp Vault Deployment on EKS

locals {
  common_labels = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Vault-GitOps"
    }
  )
}

# Create Vault namespace
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace

    labels = merge(
      local.common_labels,
      {
        name = var.vault_namespace
      }
    )
  }
}

# Create Service Account for Vault
resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = var.vault_kms_role_arn
    }

    labels = local.common_labels
  }
}

# CloudWatch Log Group for Vault Audit Logs
resource "aws_cloudwatch_log_group" "vault_audit" {
  count = var.enable_audit_logs ? 1 : 0

  name              = var.cloudwatch_log_group
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name        = "vault-audit-logs"
      Environment = var.environment
    }
  )
}

# Helm Release for Vault
resource "helm_release" "vault" {
  name       = var.vault_release_name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  values = [
    yamlencode({
      global = {
        enabled = true
        tlsDisable = true  # CHANGED: Disable TLS for dev
      }

      injector = {
        enabled = var.injector_enabled
        replicas = 2
        
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }

        metrics = {
          enabled = var.metrics_enabled
        }
      }

      server = {
        enabled = true
        
        image = {
          repository = "hashicorp/vault"
          tag        = "1.15.4"
          pullPolicy = "IfNotPresent"
        }

        resources = {
          requests = {
            memory = "512Mi"
            cpu    = "500m"
          }
          limits = {
            memory = "2Gi"
            cpu    = "1000m"
          }
        }

        readinessProbe = {
          enabled = true
          path    = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
        }

        livenessProbe = {
          enabled = true
          path    = "/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200"
          initialDelaySeconds = 60
        }

        extraEnvironmentVars = {
          AWS_REGION = var.aws_region  
        }

        volumes      = []
        volumeMounts = []

        serviceAccount = {
          create = false
          name   = kubernetes_service_account.vault.metadata[0].name
        }

        dataStorage = {
          enabled      = true
          size         = var.vault_storage_size
          storageClass = var.vault_storage_class
        }

        auditStorage = {
          enabled = var.enable_audit_logs
          size    = "5Gi"
          storageClass = var.vault_storage_class
        }

        ha = {
          enabled  = true
          replicas = var.vault_replicas
          
          raft = {
            enabled   = true
            setNodeId = true

            config = <<-EOT
              ui = ${var.enable_ui}

              listener "tcp" {
                tls_disable = 1  # CHANGED: Disable TLS
                address = "[::]:8200"
                cluster_address = "[::]:8201"
                
                telemetry {
                  unauthenticated_metrics_access = ${var.metrics_enabled}
                }
              }

              storage "raft" {
                path = "/vault/data"
                
                retry_join {
                  leader_api_addr = "http://vault-0.vault-internal:8200"  # CHANGED: http
                }
                
                retry_join {
                  leader_api_addr = "http://vault-1.vault-internal:8200"  # CHANGED: http
                }
                
                retry_join {
                  leader_api_addr = "http://vault-2.vault-internal:8200"  # CHANGED: http
                }
              }

              seal "awskms" {
                region     = "${var.aws_region}"
                kms_key_id = "${var.kms_key_id}"
              }

              service_registration "kubernetes" {}

              telemetry {
                prometheus_retention_time = "30s"
                disable_hostname = true
              }
            EOT
          }
        }

        service = {
          enabled = true
          type    = "ClusterIP"
          
          annotations = {
            "prometheus.io/scrape" = tostring(var.metrics_enabled)
            "prometheus.io/port"   = "8200"
            "prometheus.io/path"   = "/v1/sys/metrics"
          }
        }

        ui = {
          enabled = var.enable_ui
          
          service = {
            type = "LoadBalancer"
            
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
            }
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.vault
  ]
}

