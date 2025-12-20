# 💰 Cost-Saving Strategies for AWS Deployment

## Overview

Running cloud infrastructure can be expensive. This guide shows you how to minimize costs while still getting production-like experience.

## 🎯 Target Costs

| Scenario | Standard Cost | Optimized Cost | Savings |
|----------|---------------|----------------|---------|
| Full-time learning (1 month) | £180-220 | £30-50 | 75% |
| Interview prep (2 weeks) | £90-110 | £20-30 | 70% |
| Weekend learning only | £180-220 | £15-25 | 90% |

## Strategy 1: Time-Based Scheduling

### Stop Resources When Not Using Them

**Savings: 70% of compute costs**

```bash
# Stop cluster after work hours
# Example: 6pm - 9am weekdays, all weekend
# Usage: 8 hours/day × 5 days = 40 hours/week
# Savings: 76% of time = 76% of compute costs

# Automated scheduling (AWS Lambda)
# Stop nodes at 6pm
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <node-group-name> \
  --min-size 0 \
  --max-size 0 \
  --desired-capacity 0

# Start nodes at 9am
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <node-group-name> \
  --min-size 2 \
  --max-size 3 \
  --desired-capacity 2
```

**Cost Example:**
```
Full-time (24/7):     £90/month (EC2)
Business hours only:  £25/month (EC2)
Savings:              £65/month
```

### Weekend-Only Learning

**Savings: 90% of compute costs**

```bash
# Deploy Friday evening, destroy Monday morning
# Usage: 2 days per week

terraform apply   # Friday 6pm
# ... learn all weekend ...
terraform destroy # Monday 9am
```

**Cost Example:**
```
Full month:       £90-110
8 days/month:     £25-30
Savings:          £65-80
```

## Strategy 2: Use Spot Instances

### EC2 Spot Instances

**Savings: 60-70% of compute costs**

```hcl
# In your terraform variables
node_capacity_type = "SPOT"

# terraform/environments/dev-lite/main.tf
resource "aws_eks_node_group" "main" {
  capacity_type  = "SPOT"
  instance_types = ["t3.small", "t3a.small", "t3.medium"]
}
```

**Cost Example:**
```
On-Demand: £45/month (2x t3.small)
Spot:      £15/month (2x t3.small)
Savings:   £30/month (67%)
```

**Trade-offs:**
- Instances can be terminated with 2-minute notice
- Good for dev/learning (not production)
- Kubernetes will reschedule pods automatically

## Strategy 3: Right-Size Instances

### Use Smaller Instance Types

**Savings: 50% per node**

```hcl
# Instead of t3.medium (2 vCPU, 4GB RAM)
node_instance_types = ["t3.small"]  # 2 vCPU, 2GB RAM

# Or even smaller for basic testing
node_instance_types = ["t3.micro"]  # 2 vCPU, 1GB RAM
```

**Cost Comparison:**
```
Instance Type  | Monthly Cost | Use Case
---------------|--------------|------------------
t3.micro       | £7.50        | Basic testing
t3.small       | £15          | Light workloads
t3.medium      | £30          | Standard dev
t3.large       | £60          | Heavy workloads
```

## Strategy 4: Reduce Node Count

### Minimize Nodes

**Savings: £15-30 per node removed**

```hcl
# Dev-Lite: 2 nodes instead of 3
node_desired_size = 2
node_min_size     = 1

# Ultra-lite: Scale to 1 when possible
node_min_size     = 1
node_desired_size = 1
```

**Cost Example:**
```
3 nodes (standard): £90/month
2 nodes (dev-lite): £60/month
1 node (ultra):     £30/month
```

## Strategy 5: Single NAT Gateway

### Use One NAT Gateway

**Savings: £70/month**

```hcl
# Already configured in dev-lite
single_nat_gateway = true

# Cost:
# 3 NAT Gateways: £105/month
# 1 NAT Gateway:  £35/month
# Savings:        £70/month
```

**Trade-off:**
- Single point of failure for internet access
- Fine for dev/learning
- Use multiple NAT Gateways in production

## Strategy 6: Disable Optional Features

### Turn Off Non-Essential Services

**Savings: £10-15/month**

```hcl
# Disable VPC Flow Logs
enable_flow_logs = false
# Save: £5/month

# Disable CloudWatch Logs
enable_cloudwatch_logs = false
# Save: £5/month

# Disable Prometheus metrics in Vault
metrics_enabled = false
# Save: £3/month

# Disable Vault audit logs to CloudWatch
enable_audit_logs = false
# Save: £5/month
```

**When to Disable:**
- Learning basic Vault operations
- Cost is priority
- Not practicing observability

**When to Enable:**
- Learning monitoring/observability
- Debugging issues
- Interview preparation (show you know these features)

## Strategy 7: Use Smaller Storage

### Reduce EBS Volume Sizes

**Savings: £5-10/month**

```hcl
# Reduce node disk size
node_disk_size = 15  # Instead of 20GB

# Reduce Vault storage
vault_storage_size = "5Gi"  # Instead of 10Gi
```

**Cost Example:**
```
Standard: 60GB total (3 nodes × 20GB) = £8/month
Reduced:  30GB total (2 nodes × 15GB) = £4/month
Savings:  £4/month
```

## Strategy 8: Regional Selection

### Choose Cheaper Regions

**Savings: 10-20% depending on region**

```hcl
# London (eu-west-2): Baseline
# Frankfurt (eu-central-1): ~5% cheaper
# US East (us-east-1): ~15% cheaper
```

**Trade-off:**
- Data residency requirements
- Latency from your location
- For learning, any region works

## Strategy 9: Resource Tagging for Tracking

### Tag Resources to Monitor Costs

```hcl
tags = {
  Project     = "vault-demo"
  Environment = "learning"
  Owner       = "your-name"
  AutoStop    = "true"  # Custom tag for automation
  BudgetAlert = "£50"   # Your budget threshold
}
```

### Set Up Cost Alerts

```bash
# AWS Cost Explorer
# Set budget alert at £50/month
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json

# budget.json
{
  "BudgetName": "VaultLearningBudget",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "GBP"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

## Strategy 10: Destroy When Not Needed

### Complete Teardown

**Savings: 100%**

```bash
# Destroy everything when not using
terraform destroy

# Cost: £0
# Downside: Need to redeploy later (20 minutes)
```

**When to Use:**
- Finished learning a module
- Taking a break for > 1 week
- Passed the interview
- Completed the project

## Combined Strategy Example

### Ultra-Budget Learning Plan

**Goal: Learn Vault on AWS for £30 total**

```
Week 1-2: Local Development
Cost: £0
- Learn Vault basics on kind
- Test all configurations
- Practice deployments

Week 3: AWS Deployment (2 days only)
Deploy Friday evening, destroy Sunday night
- Deploy to AWS Dev-Lite
- Practice cloud features
- Test AWS integrations
Cost: ~£10

Week 4: Pre-Interview Practice (5 days)
Monday-Friday, 9am-6pm only
- Deploy Monday morning
- Practice interviews
- Destroy Friday evening
Cost: ~£20

Total Cost: £30 for complete AWS experience
```

## Smart Learning Path

### Minimize AWS Usage

```
Phase 1: Local (2 weeks) - £0
- Master Vault operations
- Learn policies and auth
- Practice secrets management

Phase 2: AWS (1 week before interview) - £25
- Deploy cloud version
- Learn AWS specifics
- Practice walkthrough
- Destroy after interview

Total: £25 for interview preparation
```

## Spot Instance Setup (Detailed)

### Enable Spot Instances in Dev-Lite

```hcl
# terraform/environments/dev-lite/main.tf

# Add to EKS module
module "eks" {
  # ... other config ...
  
  # Enable Spot instances
  node_groups = {
    spot = {
      capacity_type  = "SPOT"
      instance_types = ["t3.small", "t3a.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      
      labels = {
        workload = "spot"
      }
      
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "PreferNoSchedule"
      }]
    }
  }
}
```

## Automated Scheduling (Lambda)

### Auto-Stop Nodes After Hours

```python
# lambda_stop_nodes.py
import boto3
import os

def lambda_handler(event, context):
    autoscaling = boto3.client('autoscaling')
    
    # Get node group name from environment
    asg_name = os.environ['ASG_NAME']
    
    # Scale to 0
    autoscaling.update_auto_scaling_group(
        AutoScalingGroupName=asg_name,
        MinSize=0,
        MaxSize=0,
        DesiredCapacity=0
    )
    
    return {'statusCode': 200}

# Schedule with EventBridge:
# Cron: 0 18 ? * MON-FRI * (6pm weekdays)
```

## Cost Monitoring Dashboard

### Track Your Spending

```bash
# Check current month spending
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Check daily costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost
```

## Real Budget Examples

### Example 1: Student (£0 budget)

**Strategy:** 100% local
```
Local (kind): £0/month
- Unlimited learning
- Full features
- No time pressure
```

### Example 2: Interview Prep (£50 budget)

**Strategy:** Local + AWS (targeted)
```
Local (3 weeks):         £0
AWS Dev-Lite (1 week):   £25
Spot instances:          -£10
Evening shutdown:        -£5
Final cost:              £50 for 1 month
```

### Example 3: Portfolio Building (£100 budget)

**Strategy:** AWS part-time
```
AWS Dev-Lite:            £90
Business hours only:     -£50
Weekends off:            -£15
Final cost:              £100 for 1 month
```

## Common Questions

**Q: Will Spot instances interrupt my learning?**
A: Rarely. Interruptions are infrequent, and Kubernetes handles them automatically.

**Q: Can I stop and start nodes daily?**
A: Yes! Scales to 0 at night, back to 2 in morning. Saves 60% of compute.

**Q: What if I go over budget?**
A: Set up budget alerts. AWS will email you before hitting limits.

**Q: Is local development "enough"?**
A: For learning Vault? Yes! For AWS experience? Need cloud deployment.

## Summary: Maximum Savings

```
Strategy                    | Savings
----------------------------|----------
Spot instances             | 60-70%
Business hours only        | 70%
Smaller instances          | 50%
Single NAT Gateway         | £70/month
Disable logging            | £15/month
Fewer nodes                | £15-30/node
Destroy when not using     | 100%
----------------------------|----------
Potential total savings:   | 80-90%
```

**Bottom Line:**
- Standard AWS Dev: £180-220/month
- Optimized Dev-Lite: £90-110/month
- Maximum optimization: £20-30/month

---

**Remember:** These are LEARNING environments. For production, prioritize reliability over cost savings!
