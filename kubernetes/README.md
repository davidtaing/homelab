# Kubernetes GitOps Configuration

ArgoCD applications for managing the k3s homelab cluster.

## Structure

```
kubernetes/
├── argocd/apps/
│   ├── monitoring.yaml        # Prometheus & Grafana stack
│   └── docker-registry.yaml   # Private container registry
└── README.md
```

## Quick Start

### 1. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit: https://localhost:8080 (admin / <password>)
```

### 2. Configure Repository Access (Private Repos Only)

If your repository is private, add credentials:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/argocd_homelab

# Add public key to GitHub
cat ~/.ssh/argocd_homelab.pub

# Add to ArgoCD
argocd login localhost:8080
argocd repo add git@github.com:YOUR_USERNAME/homelab.git \
  --ssh-private-key-path ~/.ssh/argocd_homelab
```

### 3. Deploy Applications

Update the repository URL in the manifests, then:

```bash
# Deploy monitoring stack
kubectl apply -f kubernetes/argocd/apps/monitoring.yaml

# Deploy docker registry
kubectl apply -f kubernetes/argocd/apps/docker-registry.yaml
```

## Applications

### Monitoring Stack

**What it includes:**
- Prometheus (metrics collection, 7 days retention)
- Grafana (dashboards and visualization)
- AlertManager (alert handling)
- Pre-configured Kubernetes dashboards

**Storage:** ~17Gi total (10Gi Prometheus, 5Gi Grafana, 2Gi AlertManager)

**Access Grafana:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Visit: http://localhost:3000 (admin / admin)
```

**Configuration:**
- Edit [argocd/apps/monitoring.yaml](argocd/apps/monitoring.yaml)
- Adjust retention, storage sizes, or k3s node IPs

### Docker Registry

**What it includes:**
- Private Docker registry
- Basic authentication support
- Image deletion enabled
- Prometheus metrics

**Storage:** 20Gi (configurable)

**Access Registry:**
```bash
# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Registry: $NODE_IP:30500"

# Login
docker login $NODE_IP:30500

# Push images
docker tag nginx:alpine $NODE_IP:30500/my-app/nginx:latest
docker push $NODE_IP:30500/my-app/nginx:latest
```

**Configuration:**
- Edit [argocd/apps/docker-registry.yaml](argocd/apps/docker-registry.yaml)
- Adjust storage size or authentication

## Troubleshooting

### Check Application Status
```bash
kubectl get applications -n argocd
kubectl describe application monitoring -n argocd
```

### Check Pods
```bash
kubectl get pods -n monitoring
kubectl get pods -n docker-registry
```

### View Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n docker-registry -l app=docker-registry
```

## Resource Usage

Both applications are optimized for 4GB RAM nodes:

- **Monitoring:** ~500Mi RAM, 100m CPU
- **Docker Registry:** ~128Mi RAM, 100m CPU

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Docker Registry](https://docs.docker.com/registry/)
