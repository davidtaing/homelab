#!/bin/bash

# Docker Registry htpasswd Secret Setup
# This script creates the Kubernetes secret for Docker Registry authentication

set -e

echo "Docker Registry Authentication Setup"
echo "====================================="
echo

# Check if htpasswd is installed
if ! command -v htpasswd &> /dev/null; then
    echo "Error: htpasswd is not installed"
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install apache2-utils"
    echo "  macOS: brew install httpd"
    exit 1
fi

# Get credentials from environment or prompt
if [ -z "$REGISTRY_USERNAME" ]; then
    read -p "Enter registry username [default: admin]: " REGISTRY_USERNAME
    REGISTRY_USERNAME=${REGISTRY_USERNAME:-admin}
fi

if [ -z "$REGISTRY_PASSWORD" ]; then
    read -sp "Enter registry password: " REGISTRY_PASSWORD
    echo
    if [ -z "$REGISTRY_PASSWORD" ]; then
        echo "Error: Password cannot be empty"
        exit 1
    fi
fi

echo
echo "Creating htpasswd file..."

# Create htpasswd file
htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > htpasswd

echo "Creating Kubernetes namespace..."
kubectl create namespace docker-registry --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Kubernetes secret..."
kubectl create secret generic registry-htpasswd \
  --from-file=htpasswd=htpasswd \
  --namespace=docker-registry \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up htpasswd file
rm -f htpasswd

echo
echo "✓ Docker Registry secret created successfully!"
echo
echo "You can now deploy the registry with:"
echo "  kubectl apply -f kubernetes/argocd/apps/docker-registry.yaml"
echo
echo "After deployment, login with:"
echo "  docker login <NODE_IP>:30500 -u $REGISTRY_USERNAME"
