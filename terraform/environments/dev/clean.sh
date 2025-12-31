#!/bin/bash
VPC_ID="vpc-06b2086bd552a2c49"
SUBNET_IDS="subnet-08c04a3a3e6d45e10 subnet-03e42b70c299e704c subnet-031ffa6a1c81f817f"
REGION="eu-west-2"

echo "🚀 NUCLEAR VPC CLEANUP STARTING..."

# 1. FIND AND RELEASE ALL ELASTIC IPS (Root cause of internet gateway error)
echo "1. Releasing ALL Elastic IPs in region $REGION..."
EIP_LIST=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[].AllocationId' --output text)
for EIP in $EIP_LIST; do
  echo "  Releasing EIP: $EIP"
  aws ec2 release-address --allocation-id $EIP --region $REGION 2>/dev/null || true
done

# 2. FIND AND DELETE ALL REMAINING RESOURCES
echo "2. Finding all resources in VPC..."

# Network Interfaces (Force detach and delete)
echo "  - Network Interfaces..."
ENI_IDS=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)
for ENI in $ENI_IDS; do
  echo "    Detaching and deleting ENI: $ENI"
  # Get attachment ID
  ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-ids $ENI --query 'NetworkInterfaces[].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
  if [ -n "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
    aws ec2 detach-network-interface --region $REGION --attachment-id $ATTACHMENT_ID --force 2>/dev/null || true
    sleep 1
  fi
  aws ec2 delete-network-interface --region $REGION --network-interface-id $ENI --force 2>/dev/null || true
done

# 3. CHECK FOR HIDDEN DEPENDENCIES IN EACH SUBNET
echo "3. Checking each subnet for hidden dependencies..."
for SUBNET in $SUBNET_IDS; do
  echo "  Subnet: $SUBNET"
  
  # Check for VPC endpoints
  echo "    - VPC Endpoints..."
  ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=subnet-id,Values=$SUBNET" --query 'VpcEndpoints[].VpcEndpointId' --output text)
  for ENDPOINT in $ENDPOINT_IDS; do
    echo "      Deleting VPC Endpoint: $ENDPOINT"
    aws ec2 delete-vpc-endpoints --region $REGION --vpc-endpoint-ids $ENDPOINT 2>/dev/null || true
  done
  
  # Check for Network ACLs
  echo "    - Network ACLs..."
  ACL_IDS=$(aws ec2 describe-network-acls --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkAcls[?Associations[?SubnetId=='$SUBNET']].NetworkAclId" --output text)
  for ACL in $ACL_IDS; do
    echo "      Deleting Network ACL: $ACL"
    aws ec2 delete-network-acl --region $REGION --network-acl-id $ACL 2>/dev/null || true
  done
done

# 4. DELETE ROUTE TABLES (except main)
echo "4. Deleting Route Tables..."
MAIN_RT=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --query 'RouteTables[].RouteTableId' --output text)
ALL_RTS=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[].RouteTableId' --output text)

for RT in $ALL_RTS; do
  if [ "$RT" != "$MAIN_RT" ]; then
    echo "  Deleting Route Table: $RT"
    # First remove all routes except local
    ROUTES=$(aws ec2 describe-route-tables --region $REGION --route-table-ids $RT --query 'RouteTables[].Routes[?DestinationCidrBlock!='"'172.31.0.0/16'"'].DestinationCidrBlock' --output text)
    for ROUTE in $ROUTES; do
      aws ec2 delete-route --region $REGION --route-table-id $RT --destination-cidr-block $ROUTE 2>/dev/null || true
    done
    # Delete route table
    aws ec2 delete-route-table --region $REGION --route-table-id $RT 2>/dev/null || true
  fi
done

# 5. DETACH INTERNET GATEWAY
echo "5. Detaching Internet Gateway..."
IGW_ID="igw-031f0b9151db9bbe5"
echo "  Detaching IGW: $IGW_ID"
aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID 2>/dev/null || true

# 6. DELETE NAT GATEWAYS
echo "6. Deleting NAT Gateways..."
NAT_IDS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text)
for NAT in $NAT_IDS; do
  echo "  Deleting NAT Gateway: $NAT"
  aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT 2>/dev/null || true
done

# Wait for NAT Gateways
if [ -n "$NAT_IDS" ]; then
  echo "  Waiting 60 seconds for NAT Gateway cleanup..."
  sleep 60
fi

# 7. FINAL CLEANUP CHECK
echo "7. Final dependency check..."
for SUBNET in $SUBNET_IDS; do
  echo "  Checking subnet $SUBNET for remaining dependencies:"
  aws ec2 describe-subnets --region $REGION --subnet-ids $SUBNET --query 'Subnets[].AvailableIpAddressCount' --output table
done

echo "✅ CLEANUP COMPLETE!"
echo ""
echo "Now run: terraform destroy -auto-approve"
