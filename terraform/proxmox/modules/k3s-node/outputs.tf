output "vm_id" {
  description = "The ID of the VM"
  value       = proxmox_vm_qemu.k3s_node.vmid
}

output "vm_name" {
  description = "The name of the VM"
  value       = proxmox_vm_qemu.k3s_node.name
}

output "ip_address" {
  description = "The IP address of the VM"
  value       = split("/", var.ip_address)[0]
}

output "ssh_host" {
  description = "SSH connection string"
  value       = "ubuntu@${split("/", var.ip_address)[0]}"
}
