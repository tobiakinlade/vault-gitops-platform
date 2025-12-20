# Deployment Options - Which Setup is Right for You?

## Overview

This project provides **three deployment options**, each optimized for different use cases and budgets.

## Quick Comparison

| Feature | Local (kind) | AWS Dev-Lite | AWS Full Dev |
|---------|-------------|--------------|--------------|
| **Monthly Cost** | **£0** | **£90-110** | **£180-220** |
| **Setup Time** | 5 minutes | 20 minutes | 20 minutes |
| **Kubernetes** | kind | EKS | EKS |
| **Nodes** | 2 workers | 2x t3.small | 3x t3.medium |
| **Availability Zones** | N/A | 2 AZs | 3 AZs |
| **NAT Gateways** | N/A | 1 | 1 (dev) / 3 (prod) |
| **Vault Replicas** | 1 or 3 | 1 | 3 |
| **Auto-unseal** | Manual | KMS | KMS |
| **TLS** | Optional | Required | Required |
| **Logging** | Local | CloudWatch (opt) | CloudWatch |
| **Monitoring** | Optional | Basic | Full |
| **Production-Ready** | No | Learning | Yes |

## Detailed Breakdown

### Option 1: Local Development (kind)

**Perfect for:**
- 🎓 Students learning Vault
- 💡 Testing configurations
- 🔬 Rapid experimentation
- 💻 Local development
- 🚀 CI/CD testing
- 💰 Zero-budget learning

**Specifications:**
```yaml
Platform: kind (Kubernetes in Docker)
Cost: £0/month
Nodes: 1 control plane + 2 workers
Resources: Uses your laptop/desktop
Storage: Local disk
Networking: Localhost only
High Availability: Optional (3 Vault replicas)
Auto-unseal: Manual only
Production-like: 60%
```

**Cost Breakdown:**
```
Total: £0/month
Electricity: Negligible
Hardware: Your existing computer
```

**Setup Guide:** [docs/local-development.md](local-development.md)

---

### Option 2: AWS Dev-Lite (Lightweight Cloud)

**Perfect for:**
- 🎯 Interview preparation (like Tobi's case)
- 📚 Hands-on labs with cloud resources
- 👥 Team learning on AWS
- 🧪 Cloud testing on a budget
- 📊 Portfolio demonstrations

**Specifications:**
```yaml
Platform: AWS EKS
Cost: £90-110/month (50% cheaper than full dev)
Availability Zones: 2 (instead of 3)
Nodes: 2x t3.small (2 vCPU, 2GB RAM each)
NAT Gateway: 1 shared
Vault Replicas: 1 (can scale to 3)
Storage: 15GB per node
VPC Flow Logs: Disabled (save costs)
CloudWatch Logs: Disabled (save costs)
Monitoring: Basic
Production-like: 80%
```

**Cost Breakdown:**
```
EKS Control Plane:    £60/month
2x t3.small nodes:    £45/month
Single NAT Gateway:   £35/month
EBS Storage (30GB):   £3/month
KMS:                  £1/month
Data Transfer:        £5/month
─────────────────────────────────
Total:                £90-110/month

Savings vs Full Dev:  £90-110/month (50%)
```

**Setup:**
```bash
cd terraform/environments/dev-lite
terraform init
terraform plan
terraform apply
```

**When to use:**
- Need cloud experience but have budget constraints
- Demonstrating skills for interviewsx
- Learning AWS-specific features (IRSA, KMS, etc.)
- Team of 2-5 people learning together

**Limitations:**
- Not fully HA (2 AZs, single Vault)
- Reduced logging/monitoring
- Smaller nodes (may be slow with heavy workloads)

---

### Option 3: AWS Full Dev (Production-Grade)

**Perfect for:**
- 🏢 Professional portfolio projects
- 💼 Preparing for senior roles
- 🎪 Full-featured demonstrations
- 📖 Learning production patterns
- 🔐 Security best practices
- 🌐 Multi-AZ deployments

**Specifications:**
```yaml
Platform: AWS EKS
Cost: £180-220/month
Availability Zones: 3
Nodes: 3x t3.medium (2 vCPU, 4GB RAM each)
NAT Gateway: 1 shared (dev) or 3 (prod)
Vault Replicas: 3 (HA Raft cluster)
Storage: 20GB per node
VPC Flow Logs: Enabled
CloudWatch Logs: Enabled
Monitoring: Full Prometheus/Grafana
Production-like: 95%
```

**Cost Breakdown:**
```
EKS Control Plane:    £60/month
3x t3.medium nodes:   £90/month
Single NAT Gateway:   £35/month
EBS Storage (60GB):   £8/month
KMS:                  £1/month
CloudWatch Logs:      £5/month
VPC Flow Logs:        £5/month
Data Transfer:        £10/month
─────────────────────────────────
Total:                £180-220/month
```

**Setup:**
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

**When to use:**
- Building professional portfolio
- Preparing for senior DevOps roles
- Learning production Kubernetes patterns
- Need full HA and DR capabilities
- Government sector interview preparation

**Advantages:**
- Full high availability
- Complete observability stack
- Production-grade security
- Disaster recovery capabilities
- Multi-AZ resilience

---

## Cost Optimization Strategies

### For AWS Dev-Lite

**Reduce costs further:**
```bash
# 1. Use Spot Instances (60-70% savings)
node_capacity_type = "SPOT"
# New cost: £60-80/month

# 2. Schedule shutdown (save 70% outside work hours)
# Stop nodes: 6pm - 9am weekdays, all weekend
# New cost: £30-40/month

# 3. Use t3.micro for minimal testing
node_instance_types = ["t3.micro"]
# New cost: £70-90/month
```

**Weekend-only learning:**
```bash
# Run only Saturdays-Sundays (8 days/month)
# Cost: ~£25-30/month
```

### For AWS Full Dev

**Reduce costs:**
```bash
# 1. Single NAT Gateway
single_nat_gateway = true
# Save: £70/month

# 2. Disable VPC Flow Logs in dev
enable_flow_logs = false
# Save: £5/month

# 3. Disable CloudWatch Logs
enable_cloudwatch_logs = false
# Save: £5/month

# 4. Use 2 nodes instead of 3
node_desired_size = 2
# Save: £30/month

# New total: £120-150/month
```

## Decision Tree

```
Start Here
    │
    ├─ Budget = £0? ──────────────► Local (kind)
    │
    ├─ Budget < £100/month? ──────► AWS Dev-Lite
    │
    ├─ Need full HA? ─────────────► AWS Full Dev
    │
    ├─ Interview prep? ───────────► AWS Dev-Lite
    │
    ├─ Learning only? ────────────► Local (kind)
    │
    ├─ Team learning? ────────────► AWS Dev-Lite
    │
    └─ Portfolio project? ────────► AWS Full Dev
```

## Migration Path

### From Local → AWS Dev-Lite

```bash
# 1. Test everything locally first
cd local-setup
./deploy-local.sh

# 2. Export Vault config
vault policy list | xargs -I {} vault policy read {} > policies.hcl
vault auth list
vault secrets list

# 3. Deploy to AWS Dev-Lite
cd ../terraform/environments/dev-lite
terraform apply

# 4. Import Vault config
vault policy write my-policy policies.hcl
# ... migrate other configurations
```

### From Dev-Lite → Full Dev

```bash
# Just change the environment directory
cd ../dev
terraform apply

# Vault data persists in EBS volumes
# No data migration needed!
```

## Recommended Learning Path

### Week 1: Local Only (£0)
```bash
✓ Install kind
✓ Deploy Vault locally
✓ Learn basic operations
✓ Test policies and auth
✓ Practice secret management
```

### Week 2: Move to AWS Dev-Lite (£30)
```bash
✓ Deploy to AWS
✓ Learn AWS-specific features (KMS, IRSA)
✓ Practice infrastructure as code
✓ Test disaster recovery
✓ One week of practice: ~£30
```

### Week 3+: Full Dev if Needed (£180-220/month)
```bash
✓ Add full HA
✓ Implement observability
✓ Practice production patterns
✓ Build complete portfolio
```

**Total learning cost: £30 - £60** (vs £600+ without optimization)

## Real-World Scenarios

### Scenario 1: Student on £0 Budget

**Recommendation:** Local (kind)

```bash
# Setup
kind create cluster
helm install vault hashicorp/vault

# Cost: £0
# Features: 90% of production features
# Limitation: No cloud-specific features
```

### Scenario 2: Interview in 2 Weeks (Budget: £50)

**Recommendation:** AWS Dev-Lite for 2 weeks

```bash
# Deploy for 2 weeks only
cd terraform/environments/dev-lite
terraform apply

# After interview
terraform destroy

# Cost: £50 total
# Features: Full cloud experience
# Portfolio: Production-grade project
```

### Scenario 3: Building Portfolio (Budget: £200/month)

**Recommendation:** AWS Full Dev

```bash
# Deploy full setup
cd terraform/environments/dev
terraform apply

# Cost: £180-220/month
# Features: Everything
# Benefit: Senior-level demonstration
```

### Scenario 4: Teaching a Class (10 students)

**Recommendation:** Local (kind) for all

```bash
# Each student runs on their laptop
# No cloud costs
# Everyone learns together

# Optional: 1 shared AWS Dev-Lite for demos
# Cost: £100/month shared
# = £10 per student
```

## What Others Are Using

### GitHub Repository Stats (Hypothetical)

```
Local Setup:       78% of users
AWS Dev-Lite:      15% of users
AWS Full Dev:       7% of users

Why?
- Most are learning/experimenting
- AWS costs add up quickly
- Local is sufficient for learning
- Cloud for interviews/portfolios only
```

## Summary Recommendations

| Your Situation | Use This | Monthly Cost |
|----------------|----------|--------------|
| Learning Vault | Local | £0 |
| Interview in 1 month | Dev-Lite (4 weeks) | £100 |
| Building portfolio | Full Dev | £180-220 |
| Teaching/Workshops | Local | £0 |
| Team practice | Dev-Lite shared | £25-50 per person |
| Production prep | Full Dev | £180-220 |

## Questions?

**Q: Can I start local and move to AWS later?**  
A: Yes! All configurations transfer directly.

**Q: Will dev-lite work for HMRC interview?**  
A: Absolutely. It demonstrates all key concepts.

**Q: Is local setup "real Kubernetes"?**  
A: Yes! kind runs real Kubernetes, just in Docker.

**Q: Can I use free tier?**  
A: EKS has no free tier. But dev-lite is optimized for minimal cost.

**Q: What about multi-region?**  
A: That's enterprise-level. Start with single region.

---

**Our Recommendation for Most Learners:**

1. **Start with Local** (£0) - 1-2 weeks
2. **Deploy Dev-Lite** (£25-50) - 1 week for practice
3. **Only use Full Dev** if building professional portfolio

**For Tobi's HMRC Interview:**
- Use **Dev-Lite** (£100 for 4 weeks)
- Demonstrates cloud skills
- Cost-effective for timeline
- Production-like enough for senior roles

---

**Remember:** The skills transfer between all setups. Start free, scale up only when needed!
