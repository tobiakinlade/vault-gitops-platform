# Security Best Practices

## Overview

This document outlines the security architecture and best practices implemented in the Vault GitOps Platform.

## Security Layers

### 1. Network Security

#### VPC Design
- **Private Subnets**: All workloads run in private subnets
- **Security Groups**: Least privilege access rules
- **Network Policies**: Kubernetes network segmentation
- **VPC Flow Logs**: Network traffic monitoring

#### Security Group Rules
```
Vault Pods:
- Ingress: Only from pods within cluster (8200, 8201)
- Egress: All (for AWS API calls, Kubernetes API)

EKS Nodes:
- Ingress: Only from EKS control plane (443, 10250)
- Egress: All

Control Plane:
- Ingress: Only from allowed CIDR blocks (443)
- Egress: All
```

### 2. Identity & Access Management

#### IRSA (IAM Roles for Service Accounts)
- Pod-level IAM permissions
- No node-level credentials
- Automatic credential rotation
- Least privilege per workload

#### Vault Authentication
```hcl
# Kubernetes Auth Method
auth "kubernetes" {
  role "demo-app" {
    bound_service_account_names      = ["demo-app"]
    bound_service_account_namespaces = ["default"]
    policies                         = ["app-policy"]
    ttl                             = 1h
  }
}
```

#### RBAC
- Kubernetes RBAC for pod actions
- Vault policies for secret access
- IAM policies for AWS resources

### 3. Data Encryption

#### At Rest
- **Secrets**: Encrypted with AWS KMS
- **Vault Storage**: Encrypted with KMS
- **EBS Volumes**: Encrypted by default
- **S3 Backups**: Server-side encryption

#### In Transit
- **Vault API**: TLS 1.2+
- **Inter-Raft**: mTLS between Vault nodes
- **Pod-to-Vault**: HTTPS only
- **AWS API**: TLS by default

### 4. Secrets Management

#### Vault Secret Engines

**KV Secrets Engine v2**
```bash
# Versioned secrets
vault kv put secret/app/config \
  database_url="postgresql://..." \
  api_key="sensitive-key"

# Rollback capability
vault kv rollback -version=2 secret/app/config
```

**Transit Engine** (Encryption as a Service)
```bash
# Encrypt data
vault write transit/encrypt/app \
  plaintext=$(base64 <<< "sensitive data")

# Decrypt data
vault write transit/decrypt/app \
  ciphertext=vault:v1:...
```

**PKI Engine** (Internal CA)
```bash
# Generate certificates
vault write pki/issue/server \
  common_name="app.example.com" \
  ttl=24h
```

**Database Engine** (Dynamic Credentials)
```bash
# Auto-generate DB credentials
vault read database/creds/readonly
# Credentials auto-rotated and revoked
```

### 5. Audit Logging

#### Vault Audit Device
```hcl
audit_device "cloudwatch" {
  type = "file"
  options = {
    file_path = "/vault/audit/audit.log"
  }
}
```

#### What's Logged
- All Vault requests
- Authentication attempts
- Secret access
- Policy changes
- Configuration updates

#### Log Retention
- CloudWatch: 90 days minimum
- S3 Archive: 7 years for compliance
- Immutable: Cannot be modified
- Encrypted: KMS encryption

### 6. Secrets Injection

#### Vault Agent Injector
```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "demo-app"
  vault.hashicorp.com/agent-inject-secret-config: "secret/data/app/config"
  vault.hashicorp.com/agent-inject-template-config: |
    {{- with secret "secret/data/app/config" -}}
    DATABASE_URL={{ .Data.data.database_url }}
    {{- end }}
```

#### Benefits
- No secrets in environment variables
- Automatic secret updates
- No application code changes
- Transparent to application

### 7. Secret Rotation

#### Automatic Rotation
```bash
# Database credentials - auto-rotated
vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  allowed_roles="readonly,readwrite" \
  connection_url="postgresql://..." \
  username="vault" \
  password="password" \
  password_rotation_statements="ALTER USER \"{{username}}\" WITH PASSWORD '{{password}}';"
```

#### Manual Rotation
```bash
# KV secrets - version controlled
vault kv put secret/app/config @new-config.json

# Rollback if needed
vault kv rollback -version=1 secret/app/config
```

### 8. Access Control Policies

#### Admin Policy
```hcl
# Full access
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

#### Application Policy
```hcl
# Read-only access to app secrets
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}

# Use transit encryption
path "transit/encrypt/app" {
  capabilities = ["update"]
}

path "transit/decrypt/app" {
  capabilities = ["update"]
}
```

#### Database Policy
```hcl
# Dynamic database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}
```

### 9. Compliance

#### Government Standards
- **NIST 800-53**: Access control, audit, encryption
- **PCI DSS**: Secret protection, audit logging
- **GDPR**: Data encryption, access logs
- **SOC 2**: Security controls, monitoring

#### Compliance Features
1. **Audit Trail**: Every access logged
2. **Encryption**: Data at rest and in transit
3. **Access Control**: Role-based permissions
4. **Monitoring**: Real-time security events
5. **Documentation**: Configuration as code

### 10. Incident Response

#### Detection
- CloudWatch alerts for:
  - Failed authentication attempts
  - Unusual access patterns
  - High error rates
  - Policy violations

#### Response
1. **Identify**: Alert triggered
2. **Contain**: Revoke compromised credentials
3. **Investigate**: Review audit logs
4. **Remediate**: Rotate secrets, update policies
5. **Document**: Post-incident report

#### Recovery
```bash
# Revoke leaked credentials
vault lease revoke -prefix database/creds/

# Rotate root credentials
vault write database/rotate-root/mydb

# Update policies
vault policy write app-policy updated-policy.hcl
```

## Security Checklist

### Pre-Production
- [ ] Vault keys stored securely (not in Git)
- [ ] TLS certificates configured
- [ ] Network policies applied
- [ ] Security groups reviewed
- [ ] Audit logging enabled
- [ ] Backup procedures tested
- [ ] DR plan documented
- [ ] Security scanning completed

### Production
- [ ] Monitor audit logs daily
- [ ] Review access patterns weekly
- [ ] Rotate root credentials monthly
- [ ] Test DR procedures quarterly
- [ ] Update dependencies quarterly
- [ ] Security audit annually

## Best Practices

### DO
✅ Use IRSA for AWS permissions
✅ Enable audit logging
✅ Encrypt all data
✅ Use least privilege policies
✅ Rotate secrets regularly
✅ Monitor access patterns
✅ Test disaster recovery
✅ Document all changes

### DON'T
❌ Store Vault keys in Git
❌ Use root token in production
❌ Disable TLS
❌ Grant excessive permissions
❌ Ignore audit logs
❌ Skip backups
❌ Hard-code secrets
❌ Share credentials

## Security Tools

### Scanning
```bash
# Trivy - Container scanning
trivy image hashicorp/vault:1.15.4

# Checkov - IaC scanning
checkov -d terraform/

# kube-bench - CIS benchmark
kube-bench --config-dir /etc/kube-bench/cfg --config /etc/kube-bench/cfg/config.yaml
```

### Monitoring
```bash
# Check Vault status
vault status

# Review audit logs
kubectl logs -n vault vault-0 -c vault

# Check security events
aws cloudwatch get-log-events --log-group-name /aws/eks/.../vault/audit
```

## Interview Talking Points

### Security Implementation
1. **Multi-Layered Defense**
   - Network, identity, data, audit layers
   - Zero trust architecture
   - Least privilege everywhere

2. **Compliance Ready**
   - NIST 800-53 controls
   - Complete audit trail
   - Encryption standards
   - Regular security reviews

3. **Automated Security**
   - Secret rotation
   - Credential management
   - Security scanning
   - Audit monitoring

4. **Incident Response**
   - Rapid detection
   - Automated containment
   - Quick recovery
   - Full documentation

5. **Continuous Improvement**
   - Regular security audits
   - Dependency updates
   - DR testing
   - Security training
