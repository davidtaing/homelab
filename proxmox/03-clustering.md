# Proxmox Cluster Setup (Optional)

This guide covers creating a Proxmox cluster to connect your two servers together.

## Do You Need Clustering?

### ✅ **Cluster Benefits:**
- **Centralized Management**: Manage both servers from one web UI
- **VM Migration**: Move running VMs between servers
- **High Availability**: Automatic VM restart on node failure
- **Shared Configuration**: Users, storage, network configs sync automatically
- **Load Distribution**: Terraform automatically spreads VMs across nodes

### ❌ **Cluster Requirements:**
- Both servers must be on same network
- Reliable network connection between servers
- Time synchronization (NTP)
- Unique hostnames
- (For HA) Shared storage (optional for basic clustering)

### 🤔 **Do You Need It for k3s?**

**Short answer: No, but it's convenient.**

**Without Cluster:**
- Terraform can still deploy to multiple Proxmox servers
- You need separate `terraform.tfvars` configs for each server
- Manage each server's web UI separately
- VMs are distributed but not centrally managed

**With Cluster:**
- Single web UI for both servers
- Single Terraform configuration
- Easier VM management
- Better for learning cluster concepts

**Recommendation for your setup:** Create a cluster. It makes management easier and you'll learn valuable HA concepts.

## Prerequisites

Before creating a cluster:

- [ ] Both Proxmox servers installed and updated
- [ ] Both servers on same network (e.g., 192.168.0.0/24)
- [ ] Unique hostnames (pve1, pve2)
- [ ] Time synchronized on both (check `timedatectl`)
- [ ] Can ping between servers
- [ ] Firewall allows corosync ports (if firewall enabled)

## Network Requirements

### Required Ports:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 5404-5405 | UDP | Corosync (cluster communication) |
| 8006 | TCP | Proxmox Web UI |
| 3128 | TCP | SPICE proxy |
| 111, 2049 | TCP/UDP | NFS (if using shared storage) |

### Verify Connectivity:

```bash
# On pve1, ping pve2
ping -c 3 192.168.0.11

# On pve2, ping pve1
ping -c 3 192.168.0.10

# Test SSH access (should work between nodes)
ssh root@192.168.0.11  # From pve1 to pve2
ssh root@192.168.0.10  # From pve2 to pve1
```

## Step 1: Prepare Both Servers

### Verify Hostnames:

```bash
# On pve1
hostname
# Should output: pve1

# On pve2
hostname
# Should output: pve2
```

If hostnames are not set correctly:

```bash
# Set hostname
hostnamectl set-hostname pve1  # or pve2

# Update /etc/hosts
nano /etc/hosts

# Add both nodes:
192.168.0.10    pve1.local pve1
192.168.0.11    pve2.local pve2
```

### Verify Time Sync:

```bash
# On both servers
timedatectl status

# Should show:
# System clock synchronized: yes
# NTP service: active

# If not synchronized:
timedatectl set-ntp true
```

**Important**: Time must be synchronized between nodes for cluster to work properly!

## Step 2: Create Cluster on First Server

### On pve1 (192.168.0.10):

```bash
# SSH into first server
ssh root@192.168.0.10

# Create cluster named "homelab-cluster"
pvecm create homelab-cluster

# Output should show:
# Corosync Cluster Engine Authentication key generator.
# Gathering 2048 bits for key from /dev/urandom.
# Writing corosync key to /etc/corosync/authkey.
# Writing corosync config to /etc/pve/corosync.conf
# Restart corosync and cluster filesystem
```

### Verify Cluster Creation:

```bash
# Check cluster status
pvecm status

# Should show something like:
# Cluster information
# -------------------
# Name:             homelab-cluster
# Config Version:   1
# Transport:        knet
# Secure auth:      on
#
# Quorum information
# ------------------
# Date:             [current date]
# Quorum provider:  corosync_votequorum
# Nodes:            1
# Node ID:          0x00000001
# Ring ID:          1.5
# Quorate:          Yes

# List cluster nodes
pvecm nodes

# Should show:
# Membership information
# ----------------------
#     Nodeid      Votes Name
#          1          1 pve1 (local)
```

## Step 3: Join Second Server to Cluster

### On pve2 (192.168.0.11):

```bash
# SSH into second server
ssh root@192.168.0.11

# Join the cluster
# Use the IP address of pve1
pvecm add 192.168.0.10

# You'll be prompted:
# Please enter superuser (root) password for '192.168.0.10': [enter pve1 root password]
#
# The authenticity of host '192.168.0.10' can't be established.
# Are you sure you want to continue connecting (yes/no)? yes
#
# [cluster joining process happens]
# Successfully added node to cluster.
```

### Verify Join:

```bash
# Check cluster status on pve2
pvecm status

# Should show:
# Nodes: 2
# Quorate: Yes

# List nodes
pvecm nodes

# Should show both nodes:
#     Nodeid      Votes Name
#          1          1 pve1
#          2          1 pve2 (local)
```

## Step 4: Verify Cluster in Web UI

1. **Login to either server's web UI**:
   - `https://192.168.0.10:8006` OR
   - `https://192.168.0.11:8006`

2. **Check Datacenter view**:
   - Click "Datacenter" in left sidebar
   - You should see **both nodes** listed:
     - pve1
     - pve2

3. **View cluster status**:
   - Datacenter → Cluster
   - Should show:
     - Cluster Name: homelab-cluster
     - Nodes: 2
     - Quorum: OK

4. **You can now manage both servers from one UI!**

## Step 5: Configure Cluster Settings (Optional)

### Set Migration Settings:

```bash
# Allow migration over the network
pvecm expected 1

# Set migration bandwidth limit (Mbps)
# In Web UI: Datacenter → Options → Migration
# Or via CLI:
cat >> /etc/pve/datacenter.cfg <<EOF
migration: secure,network=192.168.0.0/24
EOF
```

### Configure HA (High Availability):

**Note**: HA requires shared storage. For now, skip HA configuration.

If you add shared storage later (NFS, Ceph, etc.):

```bash
# Web UI: Datacenter → HA → Add
# Select: Resources, Groups, Fencing
```

## Step 6: Test Cluster

### Test 1: Create a Test VM on One Node

1. Web UI → pve1 → Create VM
2. Create a simple VM (no need to start it)
3. Notice: You can see it from both node UIs

### Test 2: Migrate VM Between Nodes

```bash
# Create test VM on pve1
qm create 100 --name test-cluster --memory 1024 --cores 1

# Migrate to pve2 (offline migration, no shared storage needed)
qm migrate 100 pve2 --online 0

# Check where VM is now
qm list

# The VM is now on pve2!

# Clean up
qm destroy 100
```

### Test 3: View from Web UI

- Login to either server's web UI
- You can manage VMs on both nodes
- Configuration is synchronized

## Understanding Cluster Quorum

**Quorum** = Minimum number of nodes needed for cluster to function.

**Your 2-node cluster:**
- Requires: 2 votes (1 per node)
- Quorum: 2 votes needed
- **Problem**: If one node goes down, cluster loses quorum!

### Solution: Add QDevice (Optional, Advanced)

For production 2-node clusters, add a quorum device (QDevice):

```bash
# On a third machine (VM, Raspberry Pi, etc.)
apt install corosync-qnetd

# On pve1
pvecm qdevice setup <qdevice-ip>
```

**For homelab**: Not critical, just be aware both nodes need to be up.

## Cluster Management Commands

### View cluster status:
```bash
pvecm status
```

### List cluster nodes:
```bash
pvecm nodes
```

### View cluster config:
```bash
cat /etc/pve/corosync.conf
```

### Check cluster logs:
```bash
journalctl -u corosync
journalctl -u pve-cluster
```

### Remove node from cluster (if needed):
```bash
# On the node to keep (pve1)
pvecm delnode pve2
```

## Troubleshooting

### Node shows offline in cluster

```bash
# Check corosync service
systemctl status corosync

# Restart corosync
systemctl restart corosync

# Check cluster communication
pvecm status
```

### Cluster not forming

```bash
# Check time sync (must be within a few seconds)
timedatectl status

# Check network connectivity
ping <other-node-ip>

# Check if ports are open
ss -tlnp | grep 5405

# Check logs
journalctl -u corosync -f
```

### "Cluster not ready - no quorum?"

```bash
# Check expected votes
pvecm expected 1

# View quorum status
corosync-quorumtool -s

# If one node is down and you need to continue:
# (Emergency only!)
pvecm expected 1
```

### Remove cluster (start over)

```bash
# On each node:
systemctl stop pve-cluster
systemctl stop corosync
pmxcfs -l  # Force local mode
rm /etc/pve/corosync.conf
rm /etc/corosync/*
rm -rf /var/lib/corosync/*
reboot
```

## How This Affects Your Terraform Setup

### With Cluster:

Your [terraform/proxmox/terraform.tfvars](../terraform/proxmox/terraform.tfvars.example) already supports clustering:

```hcl
# Terraform will distribute VMs across nodes automatically
proxmox_nodes = [
  "pve1",  # First Proxmox server
  "pve2"   # Second Proxmox server
]

# Use either node's IP for API
proxmox_api_url = "https://192.168.0.10:8006/api2/json"

# Control plane on pve1, workers distributed across both
# VM distribution:
# - homelab-k3s-control-1 (200) → pve1
# - homelab-k3s-worker-1 (210)  → pve2
# - homelab-k3s-worker-2 (211)  → pve1
# - homelab-k3s-worker-3 (212)  → pve2
# - homelab-k3s-worker-4 (213)  → pve1
# - homelab-k3s-worker-5 (214)  → pve2
```

### Without Cluster:

You'd need to:
1. Create separate Terraform configs for each server OR
2. Manually specify which VMs go on which server
3. Manage templates on each server separately

## Shared Storage Options (Optional)

For true HA and live migration, add shared storage:

### Option 1: NFS (Easiest)
```bash
# If you have a NAS
# Datacenter → Storage → Add → NFS
```

### Option 2: Ceph (Built-in)
```bash
# Install Ceph on all nodes
pveceph install

# Create Ceph cluster
pveceph init --network 192.168.0.0/24

# Add OSDs (disks)
pveceph osd create /dev/sdX
```

### Option 3: GlusterFS
- Replicated file system
- Good for small clusters

**For your setup**: Start without shared storage. Add later if you want HA.

## Best Practices

1. **Always have both nodes on UPS**
   - Sudden power loss can corrupt cluster

2. **Backup cluster config**
   ```bash
   cp /etc/pve/corosync.conf /root/corosync.conf.backup
   ```

3. **Document node IPs**
   - Keep a note of which IP belongs to which node

4. **Regular updates**
   - Update both nodes together
   - Avoid version mismatches

5. **Monitor cluster health**
   ```bash
   pvecm status  # Should always show "Quorate: Yes"
   ```

## Checklist

After clustering:

- [ ] Cluster created on pve1
- [ ] pve2 joined successfully
- [ ] Both nodes visible in web UI
- [ ] Quorum shows "Yes"
- [ ] Can access cluster from either node's IP
- [ ] Time synchronized on both nodes
- [ ] Test VM creation works
- [ ] (Optional) Test VM migration

## Next Steps

Your cluster is ready! Now proceed with:

1. **Create API token** (only need to do once, syncs across cluster)
   - Follow [03-terraform-prep.md](03-terraform-prep.md)

2. **Create cloud-init template** (create on one node, available on both)
   - Follow [04-cloud-init-template.md](04-cloud-init-template.md)

3. **Run Terraform** (will automatically use both nodes)
   - Follow [../terraform/proxmox/README.md](../terraform/proxmox/README.md)

## Additional Resources

- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- [Proxmox HA](https://pve.proxmox.com/wiki/High_Availability)
- [Corosync Documentation](https://corosync.github.io/corosync/)
