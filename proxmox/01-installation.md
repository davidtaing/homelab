# Proxmox VE Installation Guide

## Step 1: Download Proxmox VE ISO

1. Visit: https://www.proxmox.com/en/downloads/proxmox-virtual-environment
2. Download the latest Proxmox VE ISO installer
3. Current stable version: 8.x

## Step 2: Create Bootable USB

### On Linux:
```bash
# Find your USB device (be careful!)
lsblk

# Write ISO to USB (replace /dev/sdX with your USB device)
sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=1M status=progress
sync
```

### On Windows:
1. Download [Rufus](https://rufus.ie/)
2. Select Proxmox ISO
3. Select USB drive
4. Click "Start"

### On macOS:
```bash
# Find your USB device
diskutil list

# Unmount it (replace diskX with your USB)
diskutil unmountDisk /dev/diskX

# Write ISO
sudo dd if=proxmox-ve_*.iso of=/dev/rdiskX bs=1m
```

## Step 3: Boot from USB

1. Insert USB into server
2. Enter BIOS/UEFI (usually F2, F12, or Del during boot)
3. Set USB as first boot device
4. Save and reboot

## Step 4: Install Proxmox

### Installation Wizard:

1. **Welcome Screen**
   - Select "Install Proxmox VE (Graphical)"
   - Click "I agree" to EULA

2. **Target Harddisk**
   - Select your SSD/HDD
   - Click "Options" if you want to:
     - Choose filesystem (default ext4 is fine)
     - Configure RAID (if multiple disks)
   - Click "Next"

3. **Location and Time Zone**
   - Select your country
   - Select time zone
   - Select keyboard layout
   - Click "Next"

4. **Administrator Password**
   - Set a strong root password
   - Enter root email (for system notifications)
   - **IMPORTANT**: Save this password securely!
   - Click "Next"

5. **Network Configuration**

   **For Server 1 (pve1):**
   - Hostname: `pve1.local` (or `pve1.yourdomain.com`)
   - IP Address: `192.168.0.10` (choose based on your network)
   - Netmask: `255.255.255.0` (or /24)
   - Gateway: `192.168.0.1` (your router IP)
   - DNS Server: `192.168.0.1` (or 8.8.8.8)

   **For Server 2 (pve2):**
   - Hostname: `pve2.local`
   - IP Address: `192.168.0.11`
   - Netmask: `255.255.255.0`
   - Gateway: `192.168.0.1`
   - DNS Server: `192.168.0.1`

   **Network Configuration Tips:**
   - Use static IPs (easier to manage)
   - Choose IPs outside your DHCP range
   - Make sure IPs are on same subnet
   - Write down these IPs!

   Click "Next"

6. **Summary**
   - Review all settings
   - Click "Install"
   - Wait 5-10 minutes for installation

7. **Installation Complete**
   - Remove USB drive
   - Click "Reboot"

## Step 5: Verify Installation

After reboot, you should see:

```
Welcome to the Proxmox Virtual Environment. Please use your web browser to configure this server - connect to:

  https://192.168.0.10:8006/

Login with your root password
```

## Step 6: Access Web Interface

1. On your computer, open browser
2. Navigate to: `https://192.168.0.10:8006`
3. **Ignore SSL warning** (expected for self-signed cert)
   - Click "Advanced" → "Proceed"
4. Login:
   - Username: `root`
   - Password: (what you set during install)
   - Realm: `Linux PAM standard authentication`

## Step 7: Repeat for Second Server

Repeat all steps above for your second server with:
- Hostname: `pve2.local`
- IP: `192.168.0.11`

## Post-Installation Checklist

After installing both servers:

- [ ] Both servers boot successfully
- [ ] Can access web UI on both servers
- [ ] Can ping both servers from your computer
- [ ] Noted down both IP addresses
- [ ] Saved root passwords securely

## Troubleshooting

### Can't access web interface
```bash
# SSH into the server
ssh root@192.168.0.10

# Check if web service is running
systemctl status pveproxy

# Check firewall
iptables -L -n | grep 8006
```

### Network not working
```bash
# Check network configuration
ip addr show
ip route show
cat /etc/network/interfaces

# Test connectivity
ping 8.8.8.8  # Internet
ping 192.168.0.1  # Gateway
```

### Forgot root password
You'll need physical access to reset via GRUB.

## Next Steps

Proceed to [02-initial-config.md](02-initial-config.md) for initial configuration.
