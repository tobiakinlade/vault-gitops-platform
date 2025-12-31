#!/bin/bash
VPC_ID="vpc-06b2086bd552a2c49"
SUBNET_IDS="subnet-08c04a3a3e6d45e10 subnet-03e42b70c299e704c subnet-031ffa6a1c81f817f"

echo "=== Cleaning up VPC dependencies ==="

# 1. Delete Load Balancers
echo "1. Deleting Load Balancers..."
LB_ARNS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
for LB_ARN in $LB_ARNS; do
  echo "Deleting Load Balancer: $LB_ARN"
  aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
done

# 2. Delete NAT Gateways
echo "2. Deleting NAT Gateways..."
NAT_GW_IDS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[*].NatGatewayId" --output text)
for NAT_GW_ID in $NAT_GW_IDS; do
  echo "Deleting NAT Gateway: $NAT_GW_ID"
  aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
done

# Wait for NAT Gateways to be deleted
if [ ! -z "$NAT_GW_IDS" ]; then
  echo "Waiting for NAT Gateways to delete..."
  sleep 120
fi

# 3. Delete Elastic IPs
echo "3. Releasing Elastic IPs..."
EIP_ALLOCATIONS=$(aws ec2 describe-addresses --query "Addresses[?Domain=='vpc' && AssociationId!=null].AllocationId" --output text)
for EIP_ALLOC in $EIP_ALLOCATIONS; do
  echo "Releasing Elastic IP: $EIP_ALLOC"
  aws ec2 release-address --allocation-id $EIP_ALLOC
done

# 4. Delete VPC Endpoints
echo "4. Deleting VPC Endpoints..."
VPC_ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --query "VpcEndpoints[*].VpcEndpointId" --output text)
for VPC_ENDPOINT_ID in $VPC_ENDPOINT_IDS; do
  echo "Deleting VPC Endpoint: $VPC_ENDPOINT_ID"
  aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $VPC_ENDPOINT_ID
done

# 5. Delete Network Interfaces (ENIs)
echo "5. Deleting Network Interfaces..."
for subnet in $SUBNET_IDS; do
  ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$subnet" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)
  for ENI_ID in $ENI_IDS; do
    echo "Deleting ENI: $ENI_ID in subnet $subnet"
    aws ec2 delete-network-interface --network-interface-id $ENI_ID
  done
done

# 6. Delete Route Tables (non-main)
echo "6. Deleting custom Route Tables..."
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[?Main!=true]].RouteTableId" --output text)
for RT_ID in $ROUTE_TABLE_IDS; do
  echo "Deleting Route Table: $RT_ID"
  aws ec2 delete-route-table --route-table-id $RT_ID
done

echo "=== Cleanup complete. Try terraform destroy again ==="
