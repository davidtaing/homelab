# Proxmox Initial Configuration

After installing Proxmox on both servers, perform these initial configuration steps.

## Step 1: Update Proxmox (Both Servers)

### Via Web UI:
1. Login to `https://<proxmox-ip>:8006`
2. Click on node name (pve1 or pve2) in left sidebar
3. Select "Updates" → "Refresh" → "Upgrade"

### Via SSH (Recommended):
```bash
# SSH into server
ssh root@192.168.0.10

# Update package lists
apt update

# Upgrade all packages
apt full-upgrade -y

# Reboot if kernel was updated
reboot
```

**Repeat for both servers.**

## Step 2: Remove Enterprise Repository Warning

Proxmox shows a nag message about enterprise repository if you don't have a subscription.

### Option A: Via Web UI
1. Node → Shell
2. Run these commands:

```bash
# Disable enterprise repository
echo "# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repository
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update package lists
apt update
```

### Option B: Via SSH
```bash
ssh root@192.168.0.10

# Disable enterprise repo
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# Update
apt update
```

**Repeat for both servers.**

## Step 3: Configure Storage (Optional)

By default, Proxmox uses:
- **local**: VM disks (directory on /var/lib/vz)
- **local-lvm**: VM disks (LVM thin pool)

### Check Current Storage:
1. Datacenter → Storage
2. You should see `local` and `local-lvm`

### If You Want to Use Only One:

**Option: Remove local-lvm and use all space for local**
```bash
# SSH into server
ssh root@192.168.0.10

# Remove LVM volume
lvremove /dev/pve/data -y

# Extend root volume
lvresize -l +100%FREE /dev/pve/root
resize2fs /dev/mapper/pve-root

# Remove local-lvm from web UI
# Datacenter → Storage → local-lvm → Remove
```

**For your setup (6 VMs with 40GB each), default is fine.**

## Step 4: Configure Networking

### Verify Network Configuration:
```bash
# Check interfaces
ip addr show

# Check routing
ip route show

# Test internet
ping -c 3 8.8.8.8

# Test DNS
nslookup google.com
```

### Network Configuration File:
```bash
cat /etc/network/interfaces
```

Should look like:
```
auto lo
iface lo inet loopback

iface enp1s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.0.10/24
    gateway 192.168.0.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0
```

**vmbr0** is the default bridge that VMs will use.

## Step 5: Enable IOMMU (Optional - For PCIe Passthrough)

Only needed if you plan to pass through GPUs or other PCIe devices.

```bash
# Edit GRUB config
nano /etc/default/grub

# For Intel CPU, add:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"

# For AMD CPU, add:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"

# Update GRUB
update-grub

# Add modules
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

# Reboot
reboot
```

**Skip this for now unless you need PCIe passthrough.**

## Step 6: Configure Time Synchronization

Proxmox uses systemd-timesyncd by default.

```bash
# Check time sync status
timedatectl status

# Should show:
# System clock synchronized: yes
# NTP service: active

# If not, enable it
timedatectl set-ntp true
```

## Step 7: Set Up Email Notifications (Optional)

Configure email for system alerts.

### Using Gmail SMTP:
```bash
# Install dependencies
apt install libsasl2-modules -y

# Configure postfix
echo "[smtp.gmail.com]:587 your-email@gmail.com:your-app-password" > /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# Edit postfix config
nano /etc/postfix/main.cf
```

Add these lines:
```
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

```bash
# Restart postfix
systemctl restart postfix

# Test email
echo "Test from Proxmox" | mail -s "Test Email" your-email@gmail.com
```

**Skip this for now, configure later if needed.**

## Step 8: Cluster Setup

**Important**: Clustering is covered in detail in the next guide.

The cluster setup is an essential step for this homelab as it enables:
- Centralized management of both servers
- Automatic VM distribution by Terraform
- Shared configuration across nodes

**Proceed to [03-clustering.md](03-clustering.md) for complete clustering instructions.**

You can optionally skip ahead and complete basic security steps below, but clustering must be done before running Terraform.

## Step 9: Basic Security

### Change SSH Port (Optional):
```bash
nano /etc/ssh/sshd_config

# Change line:
Port 22  # Change to something like 2222

# Restart SSH
systemctl restart sshd
```

### Set Up Firewall Rules:
```bash
# Proxmox has a built-in firewall
# Configure via Web UI:
# Datacenter → Firewall → Options → Enable

# Or via CLI:
cat > /etc/pve/firewall/cluster.fw <<EOF
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -i vmbr0 -source 192.168.0.0/24 -p tcp -dport 8006
IN ACCEPT -i vmbr0 -source 192.168.0.0/24 -p tcp -dport 22
EOF
```

**Recommendation**: Enable firewall after you're comfortable with the setup.

## Step 10: Install Useful Tools

```bash
# Install helpful utilities
apt install -y \
  htop \
  iotop \
  net-tools \
  vim \
  curl \
  wget \
  git

# Optional: Install qemu-guest-agent for better VM management
apt install -y qemu-guest-agent
```

## Verification Checklist

After completing initial config on both servers:

- [ ] Both servers updated to latest packages
- [ ] No enterprise repository warnings
- [ ] Network connectivity working
- [ ] Can access both web UIs
- [ ] Time sync enabled
- [ ] Storage configured correctly
- [ ] (Optional) Cluster created and working
- [ ] Noted down all IPs and passwords

## Server Information Reference

Keep this information handy:

```
Server 1 (pve1):
- Hostname: pve1.local
- IP: 192.168.0.10
- Web UI: https://192.168.0.10:8006
- SSH: ssh root@192.168.0.10

Server 2 (pve2):
- Hostname: pve2.local
- IP: 192.168.0.11
- Web UI: https://192.168.0.11:8006
- SSH: ssh root@192.168.0.11

Network:
- Gateway: 192.168.0.1
- DNS: 192.168.0.1
- Bridge: vmbr0
```

## Troubleshooting

### Web UI slow or unresponsive
```bash
# Check system resources
htop

# Check disk space
df -h

# Check logs
journalctl -xe
```

### Network issues
```bash
# Restart networking
systemctl restart networking

# Or reboot
reboot
```

## Next Steps

Proceed to [03-terraform-prep.md](03-terraform-prep.md) to prepare for Terraform automation.
