# Homelab Infrastructure

Infrastructure as Code (IaC) for my homelab using Proxmox, Terraform, Kubernetes, and GitOps.

## Overview

This repository manages a complete homelab stack:

- **Proxmox VE** - Hypervisor cluster running on physical servers
- **Terraform** - Automated VM provisioning and K3s cluster setup
- **Kubernetes (K3s)** - Lightweight Kubernetes for running containerized workloads
- **ArgoCD** - GitOps continuous delivery for Kubernetes applications
- **Monitoring** - Prometheus and Grafana for observability
- **Private Registry** - Docker registry for custom container images

## Repository Structure

```
homelab/
├── proxmox/          # Proxmox VE setup guides
│   ├── 01-installation.md
│   ├── 02-initial-config.md
│   ├── 03-clustering.md
│   ├── 04-terraform-prep.md
│   └── 05-cloud-init-template.md
├── terraform/        # Infrastructure provisioning
│   └── proxmox/      # K3s cluster and VM automation
└── kubernetes/       # GitOps application manifests
    └── argocd/apps/  # ArgoCD applications
```

## Quick Start

### 1. Proxmox Setup

Manual setup required before automation (one-time):

```bash
cd proxmox/
# Follow guides in order:
# 1. Install Proxmox on physical servers
# 2. Configure networking and clustering
# 3. Create Terraform user and API tokens
# 4. Create cloud-init template for VMs
```

See [proxmox/README.md](proxmox/README.md) for detailed instructions.

**Key step:** [04-terraform-prep.md](proxmox/04-terraform-prep.md) covers creating the Terraform user, API tokens, and cloud-init template needed for automation.

### 2. Provision Infrastructure with Terraform

**Prerequisites:** Install [Terraform](https://developer.hashicorp.com/terraform/install) and [direnv](https://direnv.net/docs/installation.html)

Automatically provision K3s cluster:

```bash
cd terraform/proxmox/

# Configure credentials
cp .envrc.example .envrc
# Edit .envrc with your Proxmox credentials
direnv allow  # Loads environment variables from .envrc

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your network settings

# Deploy
terraform init
terraform plan
terraform apply
```

This creates:
- 2 K3s control plane nodes (HA setup)
- 4 K3s worker nodes
- 2 Docker-only VMs (created but stopped manually to save resources)
- All VMs with 4GB RAM, 2 vCPU, 40GB disk

See [terraform/proxmox/README.md](terraform/proxmox/README.md) for details.

### 3. Deploy Applications with ArgoCD

GitOps workflow for Kubernetes applications:

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy applications
kubectl apply -f kubernetes/argocd/apps/monitoring.yaml
kubectl apply -f kubernetes/argocd/apps/docker-registry.yaml
```

See [kubernetes/README.md](kubernetes/README.md) for configuration.

## Architecture

### Hardware
- 2x Proxmox nodes (physical servers)
- Clustered for HA
- Local storage per node

### Virtual Machines
- **K3s Cluster**: 6 VMs (2 control plane + 4 workers)
- **Docker VMs**: 2 VMs (optional, created but stopped)
- **Resources**: 4GB RAM, 2 vCPU per VM
- **Storage**: 40GB per K3s VM, 30GB per Docker VM
- **Network**: Bridged to home network

### Kubernetes Stack
- **K3s**: Lightweight Kubernetes distribution with HA control plane
- **ArgoCD**: GitOps continuous delivery
- **Monitoring**: Prometheus + Grafana (7-day retention)
- **Registry**: Private Docker registry for custom images
- **Ingress**: Traefik (included with K3s)

## Applications

### Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **AlertManager**: Alert routing and notifications
- **Storage**: ~17Gi (optimized for 4GB RAM nodes)

### Docker Registry
- **Private registry**: Host custom container images
- **Authentication**: Basic auth with htpasswd
- **Storage**: 20Gi (configurable)
- **Access**: NodePort on port 30500

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Hypervisor** | Proxmox VE 8.x |
| **IaC** | Terraform + Cloud-Init |
| **Orchestration** | Kubernetes (K3s) with HA |
| **GitOps** | ArgoCD |
| **Monitoring** | Prometheus + Grafana |
| **Registry** | Docker Registry v2 |
| **Ingress** | Traefik |
| **Storage** | Local PV (k3s default) |

## Workflow

### Infrastructure Changes
1. Update Terraform configuration
2. Run `terraform plan` to preview changes
3. Apply with `terraform apply`
4. Infrastructure is updated automatically

### Application Deployment
1. Update Kubernetes manifests in `kubernetes/` directory
2. Commit and push to Git
3. ArgoCD detects changes and syncs automatically
4. Applications are deployed/updated

### Monitoring & Operations
- Access Grafana dashboards for cluster metrics
- View logs with `kubectl logs`
- Scale applications with `kubectl scale`
- ArgoCD UI shows deployment status

## Resource Requirements

### Per Node
- **Current**: 4GB RAM, 2 vCPU, 40GB storage
- **Recommended**: 8GB RAM, 4 vCPU, 100GB storage for production

### Total Cluster (6 nodes)
- **RAM**: 24GB (6 × 4GB)
- **Storage**: ~240GB (VMs + applications)
- **Network**: 1Gbps recommended

## Key Features

✅ **High Availability** - 2 control plane nodes for redundancy
✅ **Declarative Infrastructure** - Everything defined as code
✅ **GitOps Workflow** - Git as single source of truth
✅ **Automated Deployments** - Push to Git, ArgoCD deploys
✅ **Self-Healing** - ArgoCD maintains desired state
✅ **Observability** - Prometheus metrics + Grafana dashboards
✅ **Private Registry** - Host custom container images
✅ **Resource Optimized** - Runs on 4GB RAM nodes

## Useful Commands

### Proxmox
```bash
# Check cluster status
pvecm status

# List VMs
qm list

# View VM config
qm config 200
```

### Terraform
```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### Kubernetes
```bash
# Get cluster info
kubectl cluster-info

# List all pods
kubectl get pods -A

# View ArgoCD apps
kubectl get applications -n argocd

# Port forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

## Troubleshooting

### Terraform Issues
- Verify Proxmox API credentials in `.envrc`
- Check Proxmox API token permissions
- Ensure cloud-init template exists (VM ID 9000)

### Kubernetes Issues
- Check node status: `kubectl get nodes`
- View pod logs: `kubectl logs -n <namespace> <pod-name>`
- Check ArgoCD sync status: `kubectl get applications -n argocd`

### Connectivity Issues
- Verify VM IP addresses match Terraform configuration
- Check firewall rules on Proxmox hosts
- Ensure VMs can reach each other and the internet

## Security Notes

- **API Tokens**: Store Proxmox API tokens in `.envrc` (gitignored)
- **Secrets**: Use Kubernetes secrets for sensitive data
- **Registry Auth**: Configure authentication for Docker registry
- **Network**: Consider VLANs for network isolation
- **Updates**: Regularly update Proxmox, K3s, and applications

## Future Enhancements

- [ ] Add cert-manager for TLS certificates
- [ ] Implement backup solution (Velero)
- [ ] Add persistent storage (Longhorn or Rook-Ceph)
- [ ] Configure ingress with custom domain
- [ ] Add more monitoring dashboards
- [ ] Implement GitOps for Terraform with Atlantis
- [ ] Add CI/CD pipeline for custom applications

## Contributing

This is a personal homelab project, but feel free to use it as inspiration for your own setup!

## License

MIT

## Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [K3s Documentation](https://docs.k3s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)
