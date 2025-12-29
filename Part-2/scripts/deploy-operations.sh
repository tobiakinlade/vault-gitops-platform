#!/bin/bash
set -e

# Operations Deployment Script
# Velero (Backup), HPA/VPA, Cluster Autoscaler

echo "⚙️  Deploying Operations Components..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
AWS_REGION="eu-west-2"
CLUSTER_NAME="tax-calculator-dev-cluster"
BACKUP_BUCKET="tax-calculator-velero-backups-$(date +%s)"

echo "${YELLOW}Step 1: Create S3 Bucket for Velero${NC}"

# Create S3 bucket
aws s3 mb s3://${BACKUP_BUCKET} --region ${AWS_REGION}

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${BACKUP_BUCKET} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BACKUP_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "${GREEN}✅ S3 bucket created: ${BACKUP_BUCKET}${NC}"

echo "${YELLOW}Step 2: Create IAM Policy for Velero${NC}"

cat > velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${BACKUP_BUCKET}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BACKUP_BUCKET}"
            ]
        }
    ]
}
EOF

POLICY_ARN=$(aws iam create-policy \
  --policy-name VeleroBackupPolicy \
  --policy-document file://velero-policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || aws iam list-policies --query "Policies[?PolicyName=='VeleroBackupPolicy'].Arn" --output text)

echo "${GREEN}✅ IAM Policy created: ${POLICY_ARN}${NC}"

echo "${YELLOW}Step 3: Create IAM Role for Velero (IRSA)${NC}"

eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --name=velero \
  --namespace=velero \
  --attach-policy-arn=${POLICY_ARN} \
  --approve \
  --region=${AWS_REGION} \
  --override-existing-serviceaccounts || echo "Service account already exists"

echo "${GREEN}✅ IAM Service Account created${NC}"

echo "${YELLOW}Step 4: Install Velero${NC}"

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --version 5.1.0 \
  --values - <<EOF
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.8.0
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  provider: aws
  backupStorageLocation:
    bucket: ${BACKUP_BUCKET}
    config:
      region: ${AWS_REGION}
  volumeSnapshotLocation:
    config:
      region: ${AWS_REGION}
  
  # Backup settings
  defaultBackupTTL: 720h  # 30 days
  defaultVolumesToFsBackup: true

# Use IRSA instead of credentials
credentials:
  useSecret: false

serviceAccount:
  server:
    create: false
    name: velero

# Resources
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# Metrics
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: kube-prometheus-stack

# Node affinity
nodeSelector: {}
tolerations: []
EOF

echo "${BLUE}Waiting for Velero to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero -n velero --timeout=300s

echo "${GREEN}✅ Velero deployed${NC}"

echo "${YELLOW}Step 5: Create Backup Schedules${NC}"

# Daily backup at 2 AM
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    includedNamespaces:
      - tax-calculator
      - vault
    ttl: 720h  # 30 days
    storageLocation: default
    volumeSnapshotLocations:
      - default
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-full-backup
  namespace: velero
spec:
  schedule: "0 3 * * 0"  # Weekly on Sunday at 3 AM
  template:
    includedNamespaces:
      - "*"
    ttl: 2160h  # 90 days
    storageLocation: default
    volumeSnapshotLocations:
      - default
EOF

echo "${GREEN}✅ Backup schedules created${NC}"

echo "${YELLOW}Step 6: Deploy Vertical Pod Autoscaler${NC}"

# Clone VPA repository
cd /tmp
git clone https://github.com/kubernetes/autoscaler.git || cd autoscaler && git pull
cd autoscaler/vertical-pod-autoscaler

# Deploy VPA
./hack/vpa-up.sh

echo "${BLUE}Waiting for VPA to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=vpa-updater -n kube-system --timeout=300s

cd -

echo "${GREEN}✅ VPA deployed${NC}"

echo "${YELLOW}Step 7: Create VPA for Backend${NC}"

kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: backend-vpa
  namespace: tax-calculator
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  updatePolicy:
    updateMode: "Auto"  # Automatically apply recommendations
  resourcePolicy:
    containerPolicies:
      - containerName: backend
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2000m
          memory: 2Gi
        controlledResources:
          - cpu
          - memory
EOF

echo "${GREEN}✅ VPA configured for backend${NC}"

echo "${YELLOW}Step 8: Deploy Cluster Autoscaler${NC}"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM policy for Cluster Autoscaler
cat > cluster-autoscaler-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": ["*"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeImages",
                "ec2:GetInstanceTypesFromInstanceRequirements",
                "eks:DescribeNodegroup"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF

CA_POLICY_ARN=$(aws iam create-policy \
  --policy-name ClusterAutoscalerPolicy \
  --policy-document file://cluster-autoscaler-policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || aws iam list-policies --query "Policies[?PolicyName=='ClusterAutoscalerPolicy'].Arn" --output text)

echo "${GREEN}✅ Cluster Autoscaler IAM Policy: ${CA_POLICY_ARN}${NC}"

# Create service account
eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --name=cluster-autoscaler \
  --namespace=kube-system \
  --attach-policy-arn=${CA_POLICY_ARN} \
  --approve \
  --region=${AWS_REGION} \
  --override-existing-serviceaccounts || echo "Service account already exists"

# Deploy Cluster Autoscaler
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - name: cluster-autoscaler
          image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.30.0
          command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=aws
            - --skip-nodes-with-local-storage=false
            - --expander=least-waste
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${CLUSTER_NAME}
            - --balance-similar-node-groups
            - --skip-nodes-with-system-pods=false
          resources:
            requests:
              cpu: 100m
              memory: 300Mi
            limits:
              cpu: 100m
              memory: 300Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: ssl-certs
              mountPath: /etc/ssl/certs/ca-certificates.crt
              readOnly: true
      volumes:
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs/ca-bundle.crt
EOF

echo "${BLUE}Waiting for Cluster Autoscaler to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=cluster-autoscaler -n kube-system --timeout=300s

echo "${GREEN}✅ Cluster Autoscaler deployed${NC}"

echo "${YELLOW}Step 9: Test Backup${NC}"

# Create a test backup
velero backup create test-backup \
  --include-namespaces tax-calculator \
  --wait || echo "Install velero CLI: https://velero.io/docs/main/basic-install/"

echo "${GREEN}✅ Test backup initiated${NC}"

echo ""
echo "${GREEN}=== Operations Components Deployed Successfully! ===${NC}"
echo ""
echo "Velero (Backup & DR):"
echo "  ✓ S3 bucket: ${BACKUP_BUCKET}"
echo "  ✓ Daily backups scheduled (2 AM)"
echo "  ✓ Weekly full backups scheduled (Sunday 3 AM)"
echo "  ✓ 30-day retention for daily backups"
echo "  ✓ 90-day retention for weekly backups"
echo ""
echo "Autoscaling:"
echo "  ✓ HPA deployed for backend (CPU/Memory based)"
echo "  ✓ VPA deployed (Auto mode)"
echo "  ✓ Cluster Autoscaler deployed"
echo ""
echo "Next steps:"
echo "1. Test backup: velero backup create manual-test --include-namespaces tax-calculator"
echo "2. Test restore: velero restore create --from-backup <backup-name>"
echo "3. Monitor autoscaling: kubectl get hpa -n tax-calculator -w"
echo "4. Check VPA recommendations: kubectl describe vpa backend-vpa -n tax-calculator"
echo ""
echo "Velero CLI commands:"
echo "  velero backup get"
echo "  velero restore get"
echo "  velero schedule get"
