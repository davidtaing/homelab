# Proxmox Setup Scripts

Helper scripts for Proxmox setup and automation.

## create-ubuntu-template.sh

Automatically creates an Ubuntu cloud-init template on Proxmox.

### Usage

**On each Proxmox node:**

```bash
# Copy script to Proxmox
scp create-ubuntu-template.sh root@192.168.0.10:/root/

# SSH into Proxmox
ssh root@192.168.0.10

# Run the script
chmod +x create-ubuntu-template.sh
./create-ubuntu-template.sh
```

### What It Does

1. Downloads Ubuntu 22.04 (Jammy) cloud image
2. Creates VM with ID 9000
3. Imports the disk to local-lvm storage
4. Configures cloud-init settings
5. Converts VM to template
6. Optionally cleans up the downloaded image

### Configuration

You can edit these variables at the top of the script:

```bash
TEMPLATE_ID=9000           # VM ID for template
TEMPLATE_NAME="ubuntu-cloud"  # Template name
UBUNTU_VERSION="jammy"     # Ubuntu 22.04 (or "focal", "noble")
STORAGE="local-lvm"        # Storage pool
MEMORY=2048                # RAM in MB
BRIDGE="vmbr0"             # Network bridge
```

### One-Liner Install

Run directly on Proxmox without downloading:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/homelab/main/proxmox/scripts/create-ubuntu-template.sh | bash
```

**Or copy-paste the script:**

```bash
# SSH into Proxmox
ssh root@192.168.0.10

# Download script
wget https://raw.githubusercontent.com/yourusername/homelab/main/proxmox/scripts/create-ubuntu-template.sh

# Run it
chmod +x create-ubuntu-template.sh
./create-ubuntu-template.sh
```

### Manual Steps Alternative

If you prefer manual steps, see [../05-cloud-init-template.md](../05-cloud-init-template.md)

### Troubleshooting

**Script fails with "command not found":**
- Ensure you're running on a Proxmox node (not your local machine)
- Run as root: `sudo ./create-ubuntu-template.sh`

**Template already exists:**
- Script will prompt you to delete and recreate
- Or manually delete: `qm destroy 9000`

**Download fails:**
- Check internet connection: `ping ubuntu.com`
- Try different mirror or download manually first

**Verify template:**
```bash
# List all VMs and templates
qm list

# Check template details
qm config 9000

# Should show: template: 1
```

### For Both Proxmox Nodes

Run this script on **both nodes** for optimal performance:

```bash
# On pve1
ssh root@192.168.0.10
./create-ubuntu-template.sh

# On pve2
ssh root@192.168.0.11
./create-ubuntu-template.sh
```

Both use the same template ID (9000) - this is correct in a cluster!
