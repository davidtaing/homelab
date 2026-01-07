# Preparing Proxmox for Terraform

This guide covers creating the necessary API tokens and users for Terraform to manage your Proxmox infrastructure.

## Step 1: Create Terraform User

### Via Web UI:

1. Login to Proxmox: `https://192.168.0.10:8006`
2. Navigate to: **Datacenter → Permissions → Users**
3. Click **Add**
   - User name: `terraform`
   - Realm: `Proxmox VE authentication server`
   - Click **Add**

### Via SSH:
```bash
ssh root@192.168.0.10

# Create terraform user
pveum user add terraform@pve

# Verify user created
pveum user list | grep terraform
```

## Step 2: Assign Permissions to Terraform User

The terraform user needs administrative permissions to create and manage VMs.

### Via Web UI:
1. Navigate to: **Datacenter → Permissions**
2. Click **Add → User permission**
   - Path: `/`
   - User: `terraform@pve`
   - Role: `Administrator`
   - Click **Add**

### Via SSH:
```bash
# Grant Administrator role on root path
pveum aclmod / -user terraform@pve -role Administrator

# Verify permissions
pveum user permissions terraform@pve
```

## Step 3: Create API Token for Terraform

### Via Web UI:
1. Navigate to: **Datacenter → Permissions → API Tokens**
2. Click **Add**
   - User: `terraform@pve`
   - Token ID: `terraform-token`
   - Privilege Separation: **Uncheck** (important!)
   - Click **Add**
3. **IMPORTANT**: Copy the token secret immediately!
   - It will look like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - You can't retrieve it later!
   - Save it securely (password manager)

### Via SSH:
```bash
# Create token without privilege separation
pveum user token add terraform@pve terraform-token --privsep=0

# Output will show:
# ┌──────────────────────────────────────┐
# │ key                  │ value         │
# ╞══════════════════════╪═══════════════╡
# │ full-tokenid         │ terraform@... │
# ├──────────────────────┼───────────────┤
# │ info                 │ ...           │
# ├──────────────────────┼───────────────┤
# │ value                │ xxxxxxxx-...  │  <-- THIS IS YOUR SECRET!
# └──────────────────────────────────────┘

# SAVE THE VALUE (token secret) IMMEDIATELY!
```

## Step 4: Save Your Credentials

Create a secure note with these values:

```
Proxmox API Credentials for Terraform:
----------------------------------------
API URL: https://192.168.0.10:8006/api2/json
Token ID: terraform@pve!terraform-token
Token Secret: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Security Note**: Never commit these to git! They'll go in `terraform.tfvars` which is in `.gitignore`.

## Step 5: Test API Access

Verify the token works:

```bash
# Test API call (replace with your actual token)
curl -k -H "Authorization: PVEAPIToken=terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  https://192.168.0.10:8006/api2/json/nodes

# Should return JSON with node information
```

Or use this test script:

```bash
cat > test-proxmox-api.sh <<'EOF'
#!/bin/bash

API_URL="https://192.168.0.10:8006/api2/json"
TOKEN_ID="terraform@pve!terraform-token"
TOKEN_SECRET="your-token-secret-here"

echo "Testing Proxmox API access..."

response=$(curl -k -s -H "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
  "${API_URL}/nodes")

if echo "$response" | grep -q "data"; then
    echo "✓ API access successful!"
    echo "$response" | jq '.data[].node' 2>/dev/null || echo "$response"
else
    echo "✗ API access failed!"
    echo "$response"
fi
EOF

chmod +x test-proxmox-api.sh
./test-proxmox-api.sh
```

## Step 6: Verify Storage Configuration

Terraform needs to know which storage to use for VM disks.

### Check Available Storage:
```bash
# SSH into Proxmox
ssh root@192.168.0.10

# List storage
pvesm status

# Should show something like:
# Name           Type     Status           Total            Used       Available        %
# local          dir      active       237588480        13926144       211416364    5.86%
# local-lvm      lvmthin  active       237068288        24117248       212951040   10.17%
```

**For your Terraform config**:
- Your [modules/k3s-node/main.tf](../terraform/proxmox/modules/k3s-node/main.tf) uses `local-lvm`
- This is the default and should work out of the box

### If You Need to Change Storage:

Edit `terraform/proxmox/modules/k3s-node/main.tf`:

```hcl
disk {
  type    = "scsi"
  storage = "local-lvm"  # Change this if needed
  size    = var.disk_size
  slot    = 0
}
```

Common storage types:
- `local-lvm` - LVM thin pool (default, recommended)
- `local` - Directory storage
- `<custom>` - Any storage you've configured

## Step 7: Check Node Names

Terraform distributes VMs across your Proxmox nodes. Verify your node names:

```bash
# SSH into Proxmox
ssh root@192.168.0.10

# List cluster nodes
pvecm nodes

# Or if not clustered:
hostname

# Should show: pve1, pve2, or whatever you named them
```

**Update terraform.tfvars later** with your actual node names:
```hcl
proxmox_nodes = [
  "pve1",  # Replace with your actual node names
  "pve2"
]
```

## Step 8: Pre-flight Checks

Run these checks before proceeding:

```bash
# 1. Check Proxmox version
pveversion

# 2. Check available resources
pvesh get /nodes/$(hostname)/status

# 3. Check network bridges
brctl show

# 4. Check available storage space
pvesm status

# 5. Verify API is accessible
ss -tlnp | grep 8006
```

## Summary of Information Needed

For your `terraform.tfvars` file, you'll need:

```hcl
# From this guide:
proxmox_api_url       = "https://192.168.0.10:8006/api2/json"
proxmox_token_id      = "terraform@pve!terraform-token"
proxmox_token_secret  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_nodes         = ["pve1", "pve2"]

# From your network:
ip_gateway            = "192.168.0.1"

# You'll decide:
control_plane_ips     = ["192.168.0.100"]
worker_ips            = ["192.168.0.101", "192.168.0.102", "192.168.0.103", "192.168.0.104", "192.168.0.105"]
```

## Troubleshooting

### "permission denied" errors
```bash
# Check user permissions
pveum user permissions terraform@pve

# Should show:
# path: /
# role: Administrator

# If not, add permission:
pveum aclmod / -user terraform@pve -role Administrator
```

### Token authentication fails
```bash
# List tokens
pveum user token list terraform@pve

# Recreate token if needed
pveum user token remove terraform@pve terraform-token
pveum user token add terraform@pve terraform-token --privsep=0
```

### Can't reach API
```bash
# Check pveproxy service
systemctl status pveproxy

# Restart if needed
systemctl restart pveproxy

# Check firewall
iptables -L -n | grep 8006
```

## Repeat for Second Server (If Not Clustered)

If you didn't create a Proxmox cluster, repeat Steps 1-3 on your second server:

```bash
ssh root@192.168.0.11

# Create user and token on second server
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Administrator
pveum user token add terraform@pve terraform-token --privsep=0
```

**Note**: If you created a cluster, the user/token is automatically synced to all nodes.

## Security Best Practices

1. **Never commit tokens to git**
   - Already in `.gitignore` as `*.tfvars`

2. **Use separate tokens for different purposes**
   - Consider different tokens for dev/prod

3. **Rotate tokens periodically**
   ```bash
   # Remove old token
   pveum user token remove terraform@pve terraform-token

   # Create new token
   pveum user token add terraform@pve terraform-token --privsep=0
   ```

4. **Monitor API usage**
   ```bash
   # Check logs for API access
   journalctl -u pveproxy -f
   ```

## Checklist

Before proceeding to cloud-init template creation:

- [ ] Terraform user created on Proxmox
- [ ] Administrator permissions granted
- [ ] API token created (privsep=0)
- [ ] Token secret saved securely
- [ ] API access tested successfully
- [ ] Storage verified (local-lvm available)
- [ ] Node names identified
- [ ] Network information collected

## Next Steps

Proceed to [04-cloud-init-template.md](04-cloud-init-template.md) to create the Ubuntu cloud-init template that Terraform will use for VMs.
