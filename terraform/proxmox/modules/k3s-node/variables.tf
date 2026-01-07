variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to create VM on"
  type        = string
}

variable "vm_id" {
  description = "VM ID"
  type        = number
}

variable "template_name" {
  description = "Name of the template to clone"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size" {
  description = "Disk size (e.g., '32G')"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
}

variable "ip_address" {
  description = "Static IP address with CIDR (e.g., '192.168.1.100/24')"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "8.8.8.8"
}
