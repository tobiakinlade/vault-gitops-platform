server:
  image:
    repository: "hashicorp/vault"
    tag: "${vault_version}"
    pullPolicy: IfNotPresent

  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m

  serviceAccount:
    create: false
    name: "${service_account}"

  replicas: ${vault_replicas}

  ha:
    enabled: true
    replicas: ${vault_replicas}
    
    raft:
      enabled: true
      setNodeId: true
      
      config: |
        ui = true
        
        listener "tcp" {
          tls_disable = 0
          address = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
          tls_key_file  = "/vault/userconfig/vault-tls/tls.key"
          tls_client_ca_file = "/vault/userconfig/vault-tls/ca.crt"
        }

        storage "raft" {
          path = "/vault/data"
          
          retry_join {
            leader_api_addr = "https://vault-0.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
          }
          
          retry_join {
            leader_api_addr = "https://vault-1.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
          }
          
          retry_join {
            leader_api_addr = "https://vault-2.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
          }
        }

        seal "awskms" {
          region     = "${aws_region}"
          kms_key_id = "${kms_key_id}"
        }

        service_registration "kubernetes" {}

  dataStorage:
    enabled: true
    size: ${storage_size}
    storageClass: ${storage_class}
    accessMode: ReadWriteOnce

  auditStorage:
    enabled: true
    size: 10Gi
    storageClass: ${storage_class}
    accessMode: ReadWriteOnce

ui:
  enabled: true
  serviceType: "ClusterIP"

injector:
  enabled: true
  
  replicas: 2
  
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 256Mi
      cpu: 200m

  metrics:
    enabled: true
