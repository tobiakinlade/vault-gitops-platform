#!/bin/bash
set -e

# ELK Stack Deployment Script
# Day 6-7: Elasticsearch, Kibana, Fluentd

echo "🚀 Deploying ELK Stack..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Add Elastic Helm repository
echo "${YELLOW}Adding Elastic Helm repository...${NC}"
helm repo add elastic https://helm.elastic.co
helm repo update

echo "${GREEN}✅ Helm repository added${NC}"

# Create elastic-system namespace
echo "${YELLOW}Creating elastic-system namespace...${NC}"
kubectl create namespace elastic-system --dry-run=client -o yaml | kubectl apply -f -

# Deploy Elasticsearch
echo "${YELLOW}Deploying Elasticsearch cluster (3 nodes)...${NC}"
helm upgrade --install elasticsearch elastic/elasticsearch \
  --namespace elastic-system \
  --version 8.5.1 \
  --values - <<EOF
# Cluster settings
clusterName: "tax-calculator-logs"
replicas: 3  # 3-node cluster for HA

# Resources
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# Volume
volumeClaimTemplate:
  accessModes: ["ReadWriteOnce"]
  storageClassName: gp3
  resources:
    requests:
      storage: 30Gi

# JVM heap size (50% of memory)
esJavaOpts: "-Xmx1g -Xms1g"

# Security (disable for now, enable in production)
esConfig:
  elasticsearch.yml: |
    xpack.security.enabled: false
    xpack.security.enrollment.enabled: false
    xpack.security.http.ssl.enabled: false
    xpack.security.transport.ssl.enabled: false

# Service
service:
  type: ClusterIP
  annotations: {}

# Antiaffinity for HA
antiAffinity: "soft"

# Health checks
readinessProbe:
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

# Node selector (optional)
# nodeSelector:
#   node-type: logging

# Toleration
tolerations: []
EOF

echo "${BLUE}Waiting for Elasticsearch to be ready (this may take 5-10 minutes)...${NC}"
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n elastic-system --timeout=600s

echo "${GREEN}✅ Elasticsearch cluster deployed${NC}"

# Deploy Kibana
echo "${YELLOW}Deploying Kibana...${NC}"
helm upgrade --install kibana elastic/kibana \
  --namespace elastic-system \
  --version 8.5.1 \
  --values - <<EOF
# Elasticsearch connection
elasticsearchHosts: "http://elasticsearch-master:9200"

# Resources
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# Service
service:
  type: LoadBalancer
  annotations: {}
  port: 5601

# Health checks
healthCheckPath: "/api/status"
readinessProbe:
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 20

# Kibana config
kibanaConfig:
  kibana.yml: |
    server.name: kibana
    server.host: "0.0.0.0"
    elasticsearch.hosts: ["http://elasticsearch-master:9200"]
    xpack.security.enabled: false
    xpack.encryptedSavedObjects.encryptionKey: "min-32-byte-long-strong-encryption-key"

# Ingress (optional)
ingress:
  enabled: false
EOF

echo "${BLUE}Waiting for Kibana to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=kibana -n elastic-system --timeout=600s

echo "${GREEN}✅ Kibana deployed${NC}"

# Deploy Fluentd
echo "${YELLOW}Deploying Fluentd (log collector)...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: elastic-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
  - apiGroups: [""]
    resources:
      - pods
      - namespaces
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: fluentd
    namespace: elastic-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: elastic-system
data:
  fluent.conf: |
    <source>
      @type tail
      @id in_tail_container_logs
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <filter kubernetes.**>
      @type kubernetes_metadata
      @id filter_kube_metadata
      kubernetes_url "#{ENV['FLUENT_FILTER_KUBERNETES_URL'] || 'https://' + ENV.fetch('KUBERNETES_SERVICE_HOST') + ':' + ENV.fetch('KUBERNETES_SERVICE_PORT') + '/api'}"
      verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL'] || true}"
      ca_file "#{ENV['KUBERNETES_CA_FILE']}"
    </filter>

    <filter kubernetes.**>
      @type record_transformer
      <record>
        cluster_name tax-calculator-dev
        environment dev
      </record>
    </filter>

    <match kubernetes.**>
      @type elasticsearch
      @id out_es
      @log_level info
      include_tag_key true
      host elasticsearch-master.elastic-system.svc.cluster.local
      port 9200
      logstash_format true
      logstash_prefix kubernetes
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_interval 5s
        retry_forever false
        retry_max_interval 30
        chunk_limit_size 2M
        queue_limit_length 8
        overflow_action block
      </buffer>
    </match>
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: elastic-system
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccountName: fluentd
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch
          env:
            - name: FLUENT_ELASTICSEARCH_HOST
              value: "elasticsearch-master.elastic-system.svc.cluster.local"
            - name: FLUENT_ELASTICSEARCH_PORT
              value: "9200"
            - name: FLUENT_ELASTICSEARCH_SCHEME
              value: "http"
            - name: FLUENTD_SYSTEMD_CONF
              value: disable
          resources:
            limits:
              memory: 512Mi
              cpu: 500m
            requests:
              memory: 256Mi
              cpu: 100m
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: fluentd-config
              mountPath: /fluentd/etc
      terminationGracePeriodSeconds: 30
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: fluentd-config
          configMap:
            name: fluentd-config
EOF

echo "${BLUE}Waiting for Fluentd to be ready...${NC}"
sleep 10
kubectl wait --for=condition=ready pod -l app=fluentd -n elastic-system --timeout=300s

echo "${GREEN}✅ Fluentd deployed${NC}"

# Create Index Lifecycle Policy
echo "${YELLOW}Creating Elasticsearch index lifecycle management...${NC}"
sleep 30  # Wait for Elasticsearch to be fully ready

ES_POD=$(kubectl get pods -n elastic-system -l app=elasticsearch-master -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n elastic-system $ES_POD -- curl -X PUT "localhost:9200/_ilm/policy/kubernetes-policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "7d"
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'

echo "${GREEN}✅ Index lifecycle policy created${NC}"

# Get access information
echo ""
echo "${GREEN}=== ELK Stack Deployed Successfully! ===${NC}"
echo ""

# Kibana
KIBANA_URL=$(kubectl get svc kibana-kibana -n elastic-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Kibana:"
echo "  URL: http://${KIBANA_URL}:5601"
echo "  No authentication required (configure in production!)"
echo ""

# Elasticsearch
echo "Elasticsearch:"
echo "  Internal URL: http://elasticsearch-master.elastic-system.svc.cluster.local:9200"
echo "  Port-forward: kubectl port-forward svc/elasticsearch-master -n elastic-system 9200:9200"
echo ""

echo "Index Pattern:"
echo "  In Kibana, create index pattern: kubernetes-*"
echo "  Time field: @timestamp"
echo ""

echo "Next steps:"
echo "1. Access Kibana: http://${KIBANA_URL}:5601"
echo "2. Create index pattern (Stack Management → Index Patterns)"
echo "3. Explore logs in Discover"
echo "4. Create dashboards for tax-calculator application"
echo "5. Set up alerts for critical events"
echo ""
echo "Log Retention:"
echo "  - Hot phase: 7 days"
echo "  - Total retention: 90 days"
echo "  - Automatic deletion after 90 days"
