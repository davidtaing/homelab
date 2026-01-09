variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox-host:8006/api2/json)"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (e.g., terraform@pve!terraform-token). Can be set via TF_VAR_proxmox_token_id env var."
  type        = string
  default     = null
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret. Can be set via TF_VAR_proxmox_token_secret env var."
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API (use true for self-signed certs)"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "SSH public key to add to VMs"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "homelab-k3s"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 2
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 4
}

variable "vm_template_name" {
  description = "Name of the Ubuntu cloud-init template in Proxmox"
  type        = string
  default     = "ubuntu-cloud"
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory in MB per VM"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size for VMs (e.g., '40G')"
  type        = string
  default     = "40G"
}

variable "network_bridge" {
  description = "Network bridge to use (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "ip_gateway" {
  description = "Network gateway IP"
  type        = string
}

variable "ip_cidr" {
  description = "CIDR notation for subnet mask (e.g., /24)"
  type        = string
  default     = "/24"
}

variable "control_plane_ips" {
  description = "List of static IPs for control plane nodes"
  type        = list(string)
}

variable "worker_ips" {
  description = "List of static IPs for worker nodes"
  type        = list(string)
}

variable "proxmox_nodes" {
  description = "List of Proxmox node names to distribute VMs across"
  type        = list(string)
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "k3s_token" {
  description = "K3s cluster token (will be generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}
