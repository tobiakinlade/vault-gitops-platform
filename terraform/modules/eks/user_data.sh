#!/bin/bash
# EKS Node Bootstrap Script
# This script is executed when nodes start up

set -o xtrace

# Bootstrap the node
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_extra_args}

# Additional security hardening
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

# Enable CloudWatch Logs agent
yum install -y amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
