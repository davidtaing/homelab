# Local DNS Setup for *.local Domains

This guide covers setting up local DNS resolution for `*.local` domains to point to your k3s cluster. This eliminates the need to manually add each service to `/etc/hosts`.

## Overview

By setting up wildcard DNS for `*.local`, you can access services like:
- https://argocd.local
- https://grafana.local
- https://registry.local

All domains will automatically resolve to your k3s control plane node (e.g., `192.168.0.100`).

---

## Method 1: dnsmasq (Recommended for Linux/macOS)

dnsmasq is a lightweight DNS forwarder that can handle wildcard domains.

### Ubuntu/Debian

**Install dnsmasq:**
```bash
sudo apt update
sudo apt install dnsmasq
```

**Configure wildcard domain:**
```bash
# Create dnsmasq config for *.local
echo "address=/.local/192.168.0.100" | sudo tee /etc/dnsmasq.d/local-domain.conf

# Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
```

**Configure system to use dnsmasq:**
```bash
# Edit NetworkManager to use dnsmasq
sudo tee /etc/NetworkManager/conf.d/dns.conf <<EOF
[main]
dns=dnsmasq
EOF

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

**Verify:**
```bash
# Test DNS resolution
nslookup argocd.local
dig argocd.local

# Should resolve to 192.168.0.100
```

### macOS

**Install dnsmasq via Homebrew:**
```bash
brew install dnsmasq
```

**Configure wildcard domain:**
```bash
# Configure dnsmasq
echo "address=/.local/192.168.0.100" >> $(brew --prefix)/etc/dnsmasq.conf

# Start dnsmasq
sudo brew services start dnsmasq
```

**Configure macOS to use dnsmasq for .local:**
```bash
# Create resolver directory if it doesn't exist
sudo mkdir -p /etc/resolver

# Configure .local domain to use dnsmasq
sudo tee /etc/resolver/local <<EOF
nameserver 127.0.0.1
EOF
```

**Verify:**
```bash
# Test DNS resolution
nslookup argocd.local
scutil --dns | grep -A 3 "resolver #"

# Should resolve to 192.168.0.100
```

**Note:** macOS uses `.local` for Bonjour/mDNS by default. Using this method overrides that behavior for your custom services.

---

## Method 2: Pi-hole (Recommended for Network-Wide DNS)

If you run Pi-hole on your network, you can configure it to handle `*.local` domains for all devices.

**Configure Pi-hole:**

1. Access Pi-hole admin interface: http://pi.hole/admin

2. Go to **Local DNS** → **DNS Records**

3. Add a wildcard entry:
   - Domain: `local`
   - IP Address: `192.168.0.100`
   - Click "Add"

4. Or via command line on Pi-hole:
```bash
# SSH to Pi-hole
ssh pi@pi-hole

# Add wildcard DNS
echo "address=/.local/192.168.0.100" | sudo tee -a /etc/dnsmasq.d/02-local-domain.conf

# Restart Pi-hole DNS
pihole restartdns
```

**Configure clients to use Pi-hole:**
- Set DNS server to Pi-hole IP on router (DHCP)
- Or manually on each device

---

## Method 3: Router DNS Override

Some routers allow custom DNS entries or dnsmasq configuration.

### Example: OpenWrt/DD-WRT

**SSH to router:**
```bash
ssh root@192.168.0.1
```

**Add dnsmasq config:**
```bash
# Add wildcard DNS entry
echo "address=/.local/192.168.0.100" >> /etc/dnsmasq.conf

# Restart dnsmasq
/etc/init.d/dnsmasq restart
```

### Example: UniFi

1. Go to **Settings** → **Networks**
2. Edit your LAN network
3. Under **DHCP Name Server**, set to "Manual"
4. Add custom DNS entries (limited, may need Pi-hole instead)

---

## Method 4: /etc/hosts (Fallback - Per Service)

If you can't set up wildcard DNS, manually add each service to `/etc/hosts`.

**Add entries:**
```bash
# Edit /etc/hosts
sudo tee -a /etc/hosts <<EOF
192.168.0.100 argocd.local
192.168.0.100 grafana.local
192.168.0.100 registry.local
EOF
```

**Verify:**
```bash
ping argocd.local
```

**Limitations:**
- Must update for each new service
- Only works on the local machine
- No wildcard support

---

## Method 5: Windows DNS Setup

### Option A: dnsmasq via WSL2

If you use WSL2, you can run dnsmasq in WSL and configure Windows to use it.

**In WSL:**
```bash
sudo apt update
sudo apt install dnsmasq

# Configure dnsmasq
echo "address=/.local/192.168.0.100" | sudo tee /etc/dnsmasq.d/local-domain.conf

# Start dnsmasq
sudo systemctl start dnsmasq
```

**In Windows:**
1. Get WSL2 IP: `wsl hostname -I`
2. Open Network Settings → Change adapter settings
3. Right-click your network → Properties → IPv4 → Properties
4. Set Preferred DNS to WSL2 IP
5. Set Alternate DNS to `8.8.8.8`

### Option B: Windows hosts file

**Edit hosts file:**
```powershell
# Run PowerShell as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add entries:
192.168.0.100 argocd.local
192.168.0.100 grafana.local
192.168.0.100 registry.local
```

**Flush DNS cache:**
```powershell
ipconfig /flushdns
```

---

## Verification

After setting up DNS, verify it works:

```bash
# Test DNS resolution
nslookup argocd.local
nslookup grafana.local
nslookup anyname.local  # Should all resolve to 192.168.0.100

# Test with curl
curl -k https://argocd.local  # Should connect (ignore cert warnings)
```

---

## Troubleshooting

### DNS not resolving

**Check DNS server:**
```bash
# Linux/macOS
cat /etc/resolv.conf

# Should include your DNS server (127.0.0.1 for dnsmasq)
```

**Check dnsmasq is running:**
```bash
# Linux
sudo systemctl status dnsmasq

# macOS
brew services list | grep dnsmasq
```

**Flush DNS cache:**
```bash
# Ubuntu/Debian
sudo systemd-resolve --flush-caches

# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Windows
ipconfig /flushdns
```

### Conflicts with mDNS (.local)

macOS and some Linux systems use `.local` for Bonjour/mDNS. If you experience conflicts:

**Option 1:** Use a different TLD (e.g., `.home`, `.lan`)
```bash
# Change IngressRoute to use .home instead
match: Host(`argocd.home`)
```

**Option 2:** Disable mDNS (not recommended)
```bash
# Ubuntu - disable avahi
sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon
```

### Still not working

**Use /etc/hosts as temporary solution:**
```bash
echo "192.168.0.100 argocd.local" | sudo tee -a /etc/hosts
```

---

## Recommended Setup

For a homelab environment:

1. **Single User (Linux/macOS)**: Use dnsmasq locally
2. **Multiple Devices**: Set up Pi-hole for network-wide DNS
3. **Router Support**: Configure dnsmasq on router
4. **Windows Only**: Use hosts file or WSL2 + dnsmasq

---

## Changing the IP Address

If your k3s control plane IP changes, update the DNS configuration:

**dnsmasq:**
```bash
# Edit the config
sudo nano /etc/dnsmasq.d/local-domain.conf
# Change: address=/.local/NEW_IP

# Restart
sudo systemctl restart dnsmasq  # Linux
sudo brew services restart dnsmasq  # macOS
```

**Pi-hole:**
```bash
# Edit and restart
sudo nano /etc/dnsmasq.d/02-local-domain.conf
pihole restartdns
```

---

## Next Steps

After DNS is configured:

1. Deploy applications with Traefik IngressRoutes
2. Access services via friendly URLs (https://argocd.local)
3. No need to remember IPs or ports
4. Add new services without updating DNS

See [argocd/SETUP.md](argocd/SETUP.md) for ArgoCD ingress configuration.
