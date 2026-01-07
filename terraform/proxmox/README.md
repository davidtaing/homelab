# Proxmox K3s Terraform Project

This Terraform project provisions Ubuntu VMs on Proxmox and sets up a K3s Kubernetes cluster.

## Architecture

### K3s Cluster
- **1 Control Plane Node**: Runs the K3s server (VM ID 200)
- **5 Worker Nodes**: Run K3s agents (VM IDs 210-214)
- **Resources per VM**: 2 vCPU, 4GB RAM, 40GB disk

### Docker VMs (Optional - Enabled by Default)
- **2 Docker-only VMs**: One per Proxmox node (VM IDs 300-301)
- **Resources per VM**: 2 vCPU, 4GB RAM, 30GB disk
- **Auto-start**: No (VMs remain stopped to save resources)
- **IPs**: 192.168.0.150, 192.168.0.151

## Prerequisites

### 1. Install Terraform

https://developer.hashicorp.com/terraform/install

### 2. Proxmox Setup

1. Create a Terraform user in Proxmox:
```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Administrator
pveum user token add terraform@pve terraform-token --privsep=0
```

2. Note the token ID and secret for the terraform.tfvars file

3. Prepare an Ubuntu cloud-init template:
```bash
# On your Proxmox host
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qm create 9000 --name ubuntu-cloud --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

## Usage

1. Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your Proxmox details:
```bash
nano terraform.tfvars
```

3. Initialize Terraform:
```bash
terraform init
```

4. Review the plan:
```bash
terraform plan
```

5. Apply the configuration:
```bash
terraform apply
```

6. After provisioning, get the K3s kubeconfig:
```bash
# SSH to the control plane node
ssh ubuntu@<control-plane-ip>
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy to your local machine and update the server address
```

## Outputs

After successful apply, Terraform will output:
- Control plane IP address
- Worker node IP addresses
- K3s cluster token location

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Docker VMs

This project includes optional Docker-only VMs that are created but remain stopped to save resources.

### What Gets Created

- 2 Docker VMs (one on each Proxmox node)
- Docker pre-installed and configured
- VMs automatically stopped after creation
- IP addresses: 192.168.0.150, 192.168.0.151

### Starting Docker VMs

```bash
# Start one or both Docker VMs
ssh root@192.168.0.10
qm start 300  # docker-host-1
qm start 301  # docker-host-2

# Or use the command from terraform output
terraform output start_docker_command
```

### Using Docker VMs

```bash
# SSH into Docker VM (after starting it)
ssh ubuntu@192.168.0.150

# Use Docker
docker ps
docker run -d -p 80:80 nginx
docker-compose up -d
```

### Stopping Docker VMs

```bash
ssh root@192.168.0.10
qm stop 300
qm stop 301
```

### Disabling Docker VMs

If you don't want Docker VMs:

1. Delete or rename `docker-nodes.tf`
2. Run `terraform apply` to remove them

Or set the count to 0 in `docker-nodes.tf`:
```hcl
count = 0  # Disables Docker VM creation
```

## Next Steps

After the K3s cluster is running, you can:
- Deploy applications via kubectl or ArgoCD
- Use the Docker VMs for legacy workloads or testing
- Create a separate Terraform project for Kubernetes resources using the Kubernetes/Helm provider
