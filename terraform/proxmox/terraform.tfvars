# Proxmox Configuration
proxmox_api_url       = "https://192.168.0.20:8006/api2/json"
# proxmox_token_id and proxmox_token_secret are read from environment variables:
# TF_VAR_proxmox_token_id and TF_VAR_proxmox_token_secret
proxmox_tls_insecure  = true

# SSH Configuration
ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/M4L8oUho/pttEMzdyGbp4ODMLXBDw7Azh2WccVIA2mCSvUkg8SZ+6tC9FinmRkSkAGY0vAic1WZMPeiquml/ncuAu+uNLzHkSDKe4MDHVZ5XyYDIpJq8h4lEogDoillEDEIkikyn28uLbBEZKRZgY9nvcm+4SfPcXXYJ9L0OBforHF6ZIj3JdgI+rjS1y0ZskeDtkPA3ZBUORa76tgondAHYf93crggQhhpFEJ5RXaeyfZK1268j5pOcHrsnxJLs8mSqeUpEM4xOJRAjhgePhS3b/rlaZi70rOd6E5DclG99nyF3A0ZU1LAQBTwWttfM6eH3nMIIA+2Hm7ldGhT0k+fwJaiwxjLW5UBRKzJyc5F6JJSQbhDT+QTTeIMJYGN8NOrh7NEzJrMSU/luIW5MMe2FJxFh8weRkAY+n9gaXFjCt/Atr6MtUS8CubOZRbsqK96qrd1WJU4HJEc2iXR81lTwj3Sk2Q3z8oFsMQ+PRdEQg2VVuVKRT6cWC/che+srjTuVOgMM+CymKahm8Lga51atm/ogMOGokGmHR86RolF9LRMtqWx4cPF3UO33e1x+Ewp8h+MvMQYLSPlT15fcWXzdtFsXdDww58WIQtXSNg4Wf2fcgXKJAUbZjX5ZuqFUaikh3DfLQB0FtDcfGQ1pYy0qQjufYhVw6f+vljDQlQ== homelab-terraform"
ssh_private_key_path  = "~/.ssh/id_rsa"

# Network Configuration
ip_gateway            = "192.168.0.1"
ip_cidr               = "/24"

# Proxmox Nodes (two servers)
proxmox_nodes = [
  "pve",
  "pve2"
]

# Control Plane IPs (1 node)
control_plane_ips = [
  "192.168.0.100"
]

# Worker IPs (5 nodes)
worker_ips = [
  "192.168.0.101",
  "192.168.0.102",
  "192.168.0.103",
  "192.168.0.104",
  "192.168.0.105"
]

# Cluster Configuration
cluster_name          = "homelab-k3s"
vm_template_name      = "ubuntu-cloud"
k3s_version           = "v1.28.5+k3s1"

# VM Resources (per VM: 2 vCPU, 4GB RAM, 40GB disk)
vm_cpu_cores          = 2
vm_memory             = 4096
vm_disk_size          = "40G"
network_bridge        = "vmbr0"

# Optional: Set a custom K3s token (leave commented to auto-generate)
# k3s_token           = ""
