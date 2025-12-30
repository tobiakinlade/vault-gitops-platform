#!/bin/bash

echo "=== Fixing Frontend LoadBalancer Access ==="
echo ""

# Get frontend LoadBalancer details
FRONTEND_LB=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$FRONTEND_LB" ]; then
  echo "❌ Frontend service doesn't have a LoadBalancer!"
  exit 1
fi

echo "Frontend LoadBalancer: ${FRONTEND_LB}"
echo ""

# Get LoadBalancer ARN
echo "Step 1: Getting LoadBalancer details..."
LB_ARN=$(aws elbv2 describe-load-balancers \
  --region eu-west-2 \
  --query "LoadBalancers[?DNSName=='${FRONTEND_LB}'].LoadBalancerArn" \
  --output text)

if [ -z "$LB_ARN" ]; then
  echo "❌ Could not find LoadBalancer ARN!"
  exit 1
fi

echo "LoadBalancer ARN: ${LB_ARN}"
echo ""

# Get security groups
echo "Step 2: Getting security groups..."
SG_IDS=$(aws elbv2 describe-load-balancers \
  --region eu-west-2 \
  --load-balancer-arns ${LB_ARN} \
  --query 'LoadBalancers[0].SecurityGroups[]' \
  --output text)

echo "Security Groups: ${SG_IDS}"
echo ""

# Open port 80
echo "Step 3: Opening port 80..."
for SG_ID in ${SG_IDS}; do
  echo "  Processing ${SG_ID}..."
  
  # Try to add the rule
  aws ec2 authorize-security-group-ingress \
    --group-id ${SG_ID} \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region eu-west-2 2>&1 | grep -v "already exists" || true
done

echo ""
echo "✅ Port 80 opened on all security groups"
echo ""

# Check target health
echo "Step 4: Checking target health..."
TG_ARNS=$(aws elbv2 describe-target-groups \
  --region eu-west-2 \
  --load-balancer-arn ${LB_ARN} \
  --query 'TargetGroups[*].TargetGroupArn' \
  --output text)

for TG_ARN in ${TG_ARNS}; do
  echo ""
  echo "Target Group: $(echo ${TG_ARN} | awk -F':' '{print $NF}')"
  aws elbv2 describe-target-health \
    --region eu-west-2 \
    --target-group-arn ${TG_ARN} \
    --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' \
    --output table
done

echo ""
echo "Step 5: Waiting 30 seconds for changes to propagate..."
sleep 30

echo ""
echo "Step 6: Testing access..."
curl -I -m 10 http://${FRONTEND_LB} 2>&1 | head -10

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Try accessing: http://${FRONTEND_LB}"
