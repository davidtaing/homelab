# ArgoCD Setup Guide

Complete guide for setting up ArgoCD and connecting your homelab repository.

## Step 1: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

## Step 2: Access ArgoCD

### Get Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

### Configure ArgoCD for Traefik Ingress

ArgoCD runs with TLS by default, but since Traefik will handle TLS termination, we need to disable it in ArgoCD:

```bash
# Disable TLS in ArgoCD server
kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--insecure"}]'

# Wait for deployment to roll out
kubectl rollout status deployment argocd-server -n argocd
```

### Access UI

#### Option A: Via Traefik Ingress (Recommended)

K3s comes with Traefik pre-installed, so we can expose ArgoCD via an IngressRoute.

**Apply the IngressRoute:**
```bash
kubectl apply -f kubernetes/argocd/argocd-ingress.yaml
```

**Setup DNS:**

For wildcard DNS (recommended - works for all `*.local` domains):
```bash
# See DNS-SETUP.md for comprehensive guide
# Quick setup with dnsmasq:
echo "address=/.local/192.168.0.100" | sudo tee /etc/dnsmasq.d/local-domain.conf
sudo systemctl restart dnsmasq
```

Or add to `/etc/hosts` (simpler but only for this service):
```bash
echo "192.168.0.100 argocd.local" | sudo tee -a /etc/hosts
```

**See [../DNS-SETUP.md](../DNS-SETUP.md) for detailed DNS configuration options.**

**Access ArgoCD:**
- URL: https://argocd.local
- Username: admin
- Password: (from command above)

**Notes:**
- The ingress uses Traefik's `websecure` entrypoint (port 443)
- Supports both Web UI and CLI access (gRPC with h2c)
- Traefik handles TLS termination
- For production, configure cert-manager for proper TLS certificates

#### Option B: Via Port Forward (Quick Testing)

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Access at: http://localhost:8080 (HTTP since we disabled TLS)
# Username: admin
# Password: (from command above)
```

### Install ArgoCD CLI (Optional but Recommended)

**Linux:**
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

**macOS:**
```bash
brew install argocd
```

**Login via CLI:**
```bash
# If using Traefik ingress
argocd login argocd.local --username admin --insecure

# If using port-forward
argocd login localhost:8080 --username admin --insecure

# Enter password when prompted
```

## Step 3: Add Your Repository to ArgoCD

Choose one of the following methods:

### Method 1: SSH Key (Recommended for Private Repos)

**Generate SSH Key (if you don't have one):**
```bash
# Generate new SSH key for ArgoCD
ssh-keygen -t ed25519 -C "argocd@homelab" -f ~/.ssh/argocd_homelab -N ""

# Display public key to add to GitHub
cat ~/.ssh/argocd_homelab.pub
```

**Add to GitHub:**
1. Go to GitHub Settings → SSH and GPG keys → New SSH key
2. Paste the public key content
3. Title: "ArgoCD Homelab"
4. Click "Add SSH key"

**Add Repository to ArgoCD via CLI:**
```bash
argocd repo add git@github.com:YOUR_USERNAME/homelab.git \
  --ssh-private-key-path ~/.ssh/argocd_homelab \
  --insecure-skip-server-verification
```

**Or via Kubernetes Secret:**
```bash
kubectl create secret generic homelab-repo \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd_homelab \
  --namespace=argocd

kubectl label secret homelab-repo \
  argocd.argoproj.io/secret-type=repository \
  --namespace=argocd

kubectl patch secret homelab-repo -n argocd --type=merge -p '{
  "stringData": {
    "url": "git@github.com:YOUR_USERNAME/homelab.git",
    "type": "git"
  }
}'
```

### Method 2: GitHub Token (Alternative for Private Repos)

**Create GitHub Personal Access Token:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Select scope: `repo` (Full control of private repositories)
4. Generate and copy the token

**Add Repository via CLI:**
```bash
argocd repo add https://github.com/YOUR_USERNAME/homelab.git \
  --username YOUR_USERNAME \
  --password ghp_xxxxxxxxxxxxxxxxxxxx
```

**Or via Kubernetes Secret:**
```bash
kubectl create secret generic homelab-repo \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=ghp_xxxxxxxxxxxxxxxxxxxx \
  --namespace=argocd

kubectl label secret homelab-repo \
  argocd.argoproj.io/secret-type=repository \
  --namespace=argocd

kubectl patch secret homelab-repo -n argocd --type=merge -p '{
  "stringData": {
    "url": "https://github.com/YOUR_USERNAME/homelab.git",
    "type": "git"
  }
}'
```

### Method 3: Public Repository (No Auth)

If your repository is public:

```bash
argocd repo add https://github.com/YOUR_USERNAME/homelab.git
```

## Step 4: Verify Repository Connection

**Via CLI:**
```bash
argocd repo list
```

**Via UI:**
1. Go to Settings → Repositories
2. Your repository should show "Successful" connection status

**Via kubectl:**
```bash
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
```

## Step 5: Update Application Manifests

Update the repository URL in your application manifests:

```bash
# Navigate to kubernetes directory
cd kubernetes/argocd/apps/

# Update monitoring.yaml
# Replace YOUR_USERNAME with your actual GitHub username
```

Edit [apps/monitoring.yaml](apps/monitoring.yaml) and [apps/docker-registry.yaml](apps/docker-registry.yaml):

```yaml
spec:
  source:
    # For SSH
    repoURL: git@github.com:YOUR_USERNAME/homelab.git

    # Or for HTTPS
    # repoURL: https://github.com/YOUR_USERNAME/homelab.git

    targetRevision: main
    path: kubernetes/argocd/apps
```

## Step 6: Deploy Applications

### Deploy Monitoring Stack

```bash
kubectl apply -f kubernetes/argocd/apps/monitoring.yaml
```

**Check status:**
```bash
# Via CLI
argocd app get kube-prometheus-stack

# Via kubectl
kubectl get application kube-prometheus-stack -n argocd
kubectl get pods -n monitoring
```

### Deploy Docker Registry

**First, create authentication secret:**

The Docker Registry requires basic authentication. Create the htpasswd secret from environment variables:

```bash
# Set credentials via environment variables
export REGISTRY_USERNAME="admin"
export REGISTRY_PASSWORD="your-secure-password"

# Run the setup script
chmod +x kubernetes/argocd/apps/create-registry-secret.sh
./kubernetes/argocd/apps/create-registry-secret.sh
```

Or create manually:

```bash
# Install htpasswd if needed
sudo apt install apache2-utils  # Ubuntu/Debian
brew install httpd              # macOS

# Create htpasswd file
htpasswd -Bbn admin your-password > htpasswd

# Create secret
kubectl create namespace docker-registry
kubectl create secret generic registry-htpasswd \
  --from-file=htpasswd=htpasswd \
  --namespace=docker-registry

# Clean up
rm htpasswd
```

**Then deploy the registry:**

```bash
kubectl apply -f kubernetes/argocd/apps/docker-registry.yaml
```

**Check status:**
```bash
argocd app get docker-registry
kubectl get pods -n docker-registry
```

## Step 7: Access Applications

### Grafana (Monitoring)

```bash
# Port forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access at: http://localhost:3000
# Username: admin
# Password: admin (or from GRAFANA_ADMIN_PASSWORD env var)
```

### Docker Registry

```bash
# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "Docker Registry: $NODE_IP:30500"

# Login with credentials
docker login $NODE_IP:30500
# Username: admin (or your configured REGISTRY_USERNAME)
# Password: (your configured REGISTRY_PASSWORD)

# Test push/pull
docker tag myimage:latest $NODE_IP:30500/myimage:latest
docker push $NODE_IP:30500/myimage:latest
```

## Troubleshooting

### Repository Connection Failed

**Check ArgoCD repo server logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50
```

**Common issues:**
- SSH key not added to GitHub
- Wrong repository URL format
- Token expired or insufficient permissions

### Application Not Syncing

**Check application status:**
```bash
argocd app get <app-name>
kubectl describe application <app-name> -n argocd
```

**Manual sync:**
```bash
argocd app sync <app-name>
```

**Check sync policy:**
```bash
argocd app get <app-name> -o yaml | grep -A5 syncPolicy
```

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Common issues:**
- Insufficient resources (check with `kubectl top nodes`)
- Image pull errors
- Storage issues (check PVCs: `kubectl get pvc -n <namespace>`)

## Managing Applications

### Sync Application

```bash
# Sync specific app
argocd app sync kube-prometheus-stack

# Sync all apps
argocd app sync --selector app.kubernetes.io/instance=kube-prometheus-stack
```

### View Application Details

```bash
# Get app status
argocd app get kube-prometheus-stack

# View resources
argocd app resources kube-prometheus-stack

# View history
argocd app history kube-prometheus-stack
```

### Delete Application

```bash
# Delete via CLI (will also delete resources)
argocd app delete kube-prometheus-stack

# Delete via kubectl (will also delete resources)
kubectl delete application kube-prometheus-stack -n argocd
```

## Updating Applications

ArgoCD automatically detects changes when you push to Git:

```bash
# Make changes to kubernetes manifests
git add kubernetes/
git commit -m "Update monitoring configuration"
git push

# ArgoCD will automatically sync if automated sync is enabled
# Or manually sync:
argocd app sync kube-prometheus-stack
```

## Security Best Practices

1. **Change Default Passwords:**
   ```bash
   # Change ArgoCD admin password
   argocd account update-password

   # Update Grafana password
   export GRAFANA_ADMIN_PASSWORD="new-secure-password"
   ./kubernetes/monitoring/kube-prometheus-stack/create-grafana-secret.sh
   ```

2. **Use SSH Keys over Tokens:**
   - SSH keys don't expire
   - More secure than personal access tokens

3. **Rotate Credentials:**
   - Regularly rotate SSH keys and tokens
   - Update secrets in Kubernetes

4. **Enable RBAC:**
   - Create separate ArgoCD users for team members
   - Use project-based access control

5. **Use Sealed Secrets:**
   - Don't commit secrets to Git
   - Use tools like Sealed Secrets or External Secrets Operator

## Next Steps

- Enable automated sync for applications
- Set up notifications (Slack, email, etc.)
- Configure SSO for ArgoCD
- Add more applications to the cluster
- Set up monitoring alerts in Grafana

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
