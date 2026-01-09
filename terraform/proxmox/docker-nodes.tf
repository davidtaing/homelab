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
      "echo 'Waiting for cloud-init...'",
      "cloud-init status --wait || true",  # Don't fail if cloud-init already finished
      "echo 'Downloading Docker installation script...'",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "echo 'Installing Docker...'",
      "sudo sh get-docker.sh",
      "echo 'Configuring Docker user permissions...'",
      "sudo usermod -aG docker ubuntu",
      "echo 'Enabling Docker service...'",
      "sudo systemctl enable docker",
      "echo 'Starting Docker service...'",
      "sudo systemctl start docker",
      "echo 'Waiting for Docker to be ready...'",
      "timeout 30 bash -c 'until sudo docker info >/dev/null 2>&1; do sleep 1; done' || true",
      "echo 'Cleaning up installation script...'",
      "rm get-docker.sh",
      "echo 'Docker installation complete!'"
    ]
  }

  # Add a trigger to detect when the VM changes and needs reprovisioning
  triggers = {
    vm_id = module.docker_host[count.index].vm_id
  }
}

# Docker VMs remain running after setup

# Output Docker host information
output "docker_hosts" {
  description = "Docker host IP addresses"
  value       = length(module.docker_host) > 0 ? [for host in module.docker_host : host.ip_address] : []
}

output "docker_host_vmids" {
  description = "Docker host VM IDs"
  value       = length(module.docker_host) > 0 ? [for host in module.docker_host : host.vm_id] : []
}
