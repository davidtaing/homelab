# Docker-only VMs
# These VMs are created with Docker installed but remain stopped to save resources
# Start them manually when needed via Proxmox UI or: qm start <vmid>
# One Docker VM per Proxmox node (2 VMs total)

module "docker_host" {
  source   = "./modules/docker-node"
  count    = length(var.proxmox_nodes)  # One per Proxmox node

  vm_name        = "docker-host-${count.index + 1}"
  vm_id          = 300 + count.index  # VM IDs: 300, 301
  target_node    = var.proxmox_nodes[count.index]
  template_name  = var.vm_template_name
  cpu_cores      = 2
  memory         = 4096
  disk_size      = "30G"
  network_bridge = var.network_bridge
  ip_address     = "192.168.0.${150 + count.index}${var.ip_cidr}"  # IPs: .150, .151
  gateway        = var.ip_gateway
  ssh_public_key = var.ssh_public_key
}

# Install Docker on these hosts
resource "null_resource" "install_docker" {
  count = length(var.proxmox_nodes)  # Match the count above

  depends_on = [module.docker_host]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.docker_host[count.index].ip_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker ubuntu",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "rm get-docker.sh"
    ]
  }
}

# Stop Docker VMs after creation and setup
resource "null_resource" "stop_docker_hosts" {
  count = length(var.proxmox_nodes)  # Match the docker_host count

  depends_on = [null_resource.install_docker]

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${element(split("://", var.proxmox_api_url), 1) != "" ? element(split(":", element(split("://", var.proxmox_api_url), 1)), 0) : "192.168.0.10"} 'qm stop ${module.docker_host[count.index].vm_id}'
    EOT
  }
}

# Output Docker host information
output "docker_hosts" {
  description = "Docker host IP addresses (VMs are stopped, start manually)"
  value       = length(module.docker_host) > 0 ? [for host in module.docker_host : host.ip_address] : []
}

output "docker_host_vmids" {
  description = "Docker host VM IDs for starting/stopping"
  value       = length(module.docker_host) > 0 ? [for host in module.docker_host : host.vm_id] : []
}

output "start_docker_command" {
  description = "Command to start Docker VMs"
  value       = length(module.docker_host) > 0 ? "qm start ${join(" && qm start ", [for host in module.docker_host : host.vm_id])}" : "No Docker VMs created"
}
