# Creating Ubuntu Cloud-Init Template

This guide walks through creating an Ubuntu cloud-init template that Terraform will clone to create your k3s VMs.

## What is Cloud-Init?

**Cloud-init** is an industry-standard method for cloud instance initialization. It allows you to:
- Set hostname
- Configure network (static IP)
- Add SSH keys
- Run commands on first boot

Your Terraform configuration uses cloud-init to automatically configure each VM.

## Quick Start: Automated Script (Recommended)

We've provided a script that automates the entire template creation process:

```bash
# Copy script to Proxmox
scp ~/homelab/proxmox/scripts/create-ubuntu-template.sh root@192.168.0.10:/root/

# SSH into Proxmox
ssh root@192.168.0.10

# Run the script
chmod +x create-ubuntu-template.sh
./create-ubuntu-template.sh
```

The script will:
- Download Ubuntu 22.04 cloud image
- Create template with VM ID 9000
- Configure cloud-init settings
- Optionally clean up downloaded image

**Then repeat on the second node for optimal performance.**

See [scripts/README.md](scripts/README.md) for details.

---

## Manual Steps (Alternative)

If you prefer to understand each step or customize the process, follow the manual instructions below.

## Step 1: Download Ubuntu Cloud Image

Cloud images are pre-built, minimal Ubuntu images designed for cloud/virtualization.

```bash
# SSH into Proxmox
ssh root@192.168.0.10

# Navigate to images directory
cd /var/lib/vz/template/iso

# Download Ubuntu 22.04 LTS (Jammy) cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Verify download
ls -lh jammy-server-cloudimg-amd64.img
```

**Alternative versions:**
```bash
# Ubuntu 24.04 LTS (Noble) - newer
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Ubuntu 20.04 LTS (Focal) - older but stable
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

**Recommendation**: Use **Ubuntu 22.04 (Jammy)** for k3s - good balance of stability and modern packages.

## Step 2: Create VM Template

### Choose a VM ID for the Template

VM IDs in Proxmox are unique identifiers. Common conventions:
- **9000-9999**: Reserved for templates
- **100-199**: VMs on first server
- **200-299**: Your k3s cluster (200-210 as configured)

We'll use **VM ID 9000** for our template.

### Create the VM

```bash
# Create VM with ID 9000
qm create 9000 \
  --name ubuntu-cloud \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0

# Explanation:
# qm create 9000        - Create VM with ID 9000
# --name ubuntu-cloud   - Template name (matches your terraform config)
# --memory 2048         - 2GB RAM (minimum for Ubuntu)
# --cores 2             - 2 CPU cores
# --net0 virtio,bridge=vmbr0  - Network on vmbr0 bridge
```

## Step 3: Import Disk Image

```bash
# Import the cloud image as a disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# This creates a disk in local-lvm storage
# Output will show: Successfully imported disk as 'unused0:local-lvm:vm-9000-disk-0'
```

## Step 4: Configure the VM

```bash
# Attach the imported disk as SCSI drive
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add cloud-init drive (required for cloud-init)
qm set 9000 --ide2 local-lvm:cloudinit

# Configure boot order (boot from SCSI disk)
qm set 9000 --boot c --bootdisk scsi0

# Add serial console (useful for debugging)
qm set 9000 --serial0 socket --vga serial0

# Make it a template
qm template 9000
```

## Step 5: Verify Template Creation

### Via Web UI:
1. Go to: `https://192.168.0.10:8006`
2. Navigate to your node (pve1)
3. You should see **9000 (ubuntu-cloud)** with a template icon
4. Click on it
5. Go to **Hardware** tab
   - Should see: SCSI disk, network, cloud-init drive

### Via CLI:
```bash
# List VMs and templates
qm list

# Should show:
#       VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID
#       9000 ubuntu-cloud         stopped    2048              2.00

# Check if it's a template
qm config 9000 | grep template
# Should output: template: 1
```

## Step 6: Test the Template (Optional but Recommended)

Create a test VM from the template to verify it works:

```bash
# Clone the template to a test VM (ID 999)
qm clone 9000 999 --name test-vm --full

# Configure cloud-init for test VM
qm set 999 --ipconfig0 ip=192.168.0.50/24,gw=192.168.0.1
qm set 999 --nameserver 8.8.8.8
qm set 999 --ciuser ubuntu
qm set 999 --sshkeys ~/.ssh/id_rsa.pub  # Your SSH public key

# Start the test VM
qm start 999

# Wait 30 seconds for boot and cloud-init

# Try to SSH (should work without password)
ssh ubuntu@192.168.0.50

# If successful, stop and delete test VM
qm stop 999
qm destroy 999
```

## Step 7: Optimize Template (Optional)

### Resize Disk (if needed)

The default cloud image is small (2GB). Your Terraform config will automatically resize to 40GB, but you can pre-expand:

```bash
# Resize template disk to 10GB (Terraform will expand further)
qm resize 9000 scsi0 +8G
```

**Note**: Terraform will handle disk sizing, so this is optional.

### Enable QEMU Guest Agent

The guest agent provides better VM management:

```bash
# Enable QEMU guest agent in template
qm set 9000 --agent enabled=1

# Note: The agent software will be installed via cloud-init on first boot
```

### Configure Default Cloud-Init Settings

Set defaults that can be overridden per VM:

```bash
# Set default DNS
qm set 9000 --nameserver "8.8.8.8 8.8.4.4"

# Set default user
qm set 9000 --ciuser ubuntu

# Note: SSH keys and IPs will be set per VM by Terraform
```

## Step 8: Verify Template in Cluster

Since you created a Proxmox cluster, the template **configuration is automatically shared** across both nodes. However, each node needs its own copy of the template disk for local VM creation.

### Option A: Let Terraform Handle It (Recommended)
Terraform will automatically use the template from the node where you created it. VMs created on pve2 will clone from pve1 over the network.

### Option B: Create Template on Both Nodes (Better Performance)
For faster VM creation, optionally create the template on the second node:

```bash
# SSH into second server
ssh root@192.168.0.11

# Copy the cloud image
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create template (same VM ID: 9000)
qm create 9000 --name ubuntu-cloud --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

**Note**: This step is optional. Terraform will work either way.

## Understanding the Template Configuration

Your template is now configured to:

1. **Clone quickly**: Linked clones are created in seconds
2. **Auto-configure network**: Via cloud-init
3. **Auto-configure SSH**: Keys injected by Terraform
4. **Auto-resize disk**: From 2GB to 40GB (by Terraform)
5. **Run first-boot scripts**: k3s installation (by Terraform)

## How Terraform Uses This Template

When you run `terraform apply`, for each VM:

```hcl
# In modules/k3s-node/main.tf
resource "proxmox_vm_qemu" "k3s_node" {
  clone = var.template_name  # "ubuntu-cloud" (the template we just created)

  # Terraform will:
  # 1. Clone the template
  # 2. Resize disk to 40GB
  # 3. Set static IP via cloud-init
  # 4. Inject SSH public key
  # 5. Start the VM
  # 6. Wait for cloud-init to complete
  # 7. Run k3s installation via SSH
}
```

## Troubleshooting

### Template creation fails
```bash
# Check available storage
pvesm status

# Check disk space
df -h /var/lib/vz

# Verify image integrity
sha256sum jammy-server-cloudimg-amd64.img
# Compare with: https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS
```

### Can't SSH to test VM
```bash
# Check VM console
qm terminal 999

# Check cloud-init logs
# (from within VM console)
sudo cloud-init status --long
sudo journalctl -u cloud-init

# Check network
ip addr show
ip route show
ping 8.8.8.8
```

### Template not appearing in Terraform
```bash
# Verify template name matches
qm list | grep ubuntu-cloud

# Template name in Terraform should match exactly:
# terraform/proxmox/variables.tf
# vm_template_name = "ubuntu-cloud"
```

## Template Management

### View template details
```bash
qm config 9000
```

### Update template

If you need to update the template later:

```bash
# Remove template flag
qm set 9000 --template 0

# Make changes (upgrade packages, etc.)
qm start 9000
# ... make changes ...
qm stop 9000

# Convert back to template
qm template 9000
```

### Delete and recreate template
```bash
# Delete template
qm destroy 9000

# Recreate following steps above
```

## Security Considerations

1. **Minimal base image**: Cloud images are minimal, reducing attack surface
2. **No default passwords**: SSH key auth only
3. **Up-to-date packages**: Update regularly
4. **Cloud-init security**:
   - SSH keys are injected securely
   - No plain-text passwords
   - Network config via secure API

## Checklist

Before proceeding to Terraform:

- [ ] Ubuntu cloud image downloaded
- [ ] Template created with VM ID 9000
- [ ] Template named "ubuntu-cloud"
- [ ] Disk imported and attached
- [ ] Cloud-init drive configured
- [ ] Template flag set (qm template)
- [ ] Template visible in Proxmox UI from either node
- [ ] (Optional) Test clone successful
- [ ] (Optional) Template disk created on both nodes for better performance

## Next Steps

Your Proxmox environment is now ready for Terraform!

**Return to the main Terraform project:**
```bash
cd ~/homelab/terraform/proxmox
```

**Next actions:**
1. Generate SSH keys (if needed)
2. Create `terraform.tfvars` with your configuration
3. Run `terraform plan` to see what will be created
4. Run `terraform apply` to deploy your k3s cluster

See the [terraform README](../terraform/proxmox/README.md) for deployment instructions.

## Additional Resources

- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Proxmox VM Templates](https://pve.proxmox.com/wiki/VM_Templates_and_Clones)
- [QEMU Guest Agent](https://pve.proxmox.com/wiki/Qemu-guest-agent)
