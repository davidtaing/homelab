#!/bin/bash

# Script to retrieve and configure kubeconfig from K3s control plane

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <control-plane-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

CONTROL_PLANE_IP=$1
KUBECONFIG_PATH="${HOME}/.kube/config-homelab"

echo "Retrieving kubeconfig from ${CONTROL_PLANE_IP}..."

# Get kubeconfig from control plane
ssh ubuntu@${CONTROL_PLANE_IP} 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
    sed "s/127.0.0.1/${CONTROL_PLANE_IP}/" > ${KUBECONFIG_PATH}

echo "Kubeconfig saved to ${KUBECONFIG_PATH}"
echo ""
echo "To use this kubeconfig, run:"
echo "  export KUBECONFIG=${KUBECONFIG_PATH}"
echo ""
echo "Or merge it with your existing config:"
echo "  KUBECONFIG=~/.kube/config:${KUBECONFIG_PATH} kubectl config view --flatten > ~/.kube/config.new"
echo "  mv ~/.kube/config.new ~/.kube/config"
echo ""
echo "Test the connection:"
echo "  kubectl --kubeconfig=${KUBECONFIG_PATH} get nodes"
