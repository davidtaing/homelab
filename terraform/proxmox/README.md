# Proxmox K3s Terraform Project

This Terraform project provisions Ubuntu VMs on Proxmox and sets up a K3s Kubernetes cluster.

## Architecture

- **1 Control Plane Node**: Runs the K3s server
- **5 Worker Nodes**: Run K3s agents
- **Resources per VM**: 2 vCPU, 4GB RAM, 32GB disk

## Prerequisites

### 1. Install Terraform

```bash
# Download and install Terraform (Linux)
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

Or use your package manager:
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

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

## Next Steps

After the K3s cluster is running, you can create a separate Terraform project for Kubernetes resources using the Kubernetes/Helm provider.
