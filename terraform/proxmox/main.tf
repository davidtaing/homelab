locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Control Plane Nodes
module "control_plane" {
  source   = "./modules/k3s-node"
  count    = var.control_plane_count

  vm_name        = "${var.cluster_name}-control-${count.index + 1}"
  vm_id          = 200 + count.index
  target_node    = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  template_name  = var.vm_template_name
  cpu_cores      = var.vm_cpu_cores
  memory         = var.vm_memory
  disk_size      = var.vm_disk_size
  network_bridge = var.network_bridge
  ip_address     = "${var.control_plane_ips[count.index]}${var.ip_cidr}"
  gateway        = var.ip_gateway
  ssh_public_key = var.ssh_public_key
}

# Worker Nodes
module "workers" {
  source   = "./modules/k3s-node"
  count    = var.worker_count

  vm_name        = "${var.cluster_name}-worker-${count.index + 1}"
  vm_id          = 210 + count.index
  target_node    = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  template_name  = var.vm_template_name
  cpu_cores      = var.vm_cpu_cores
  memory         = var.vm_memory
  disk_size      = var.vm_disk_size
  network_bridge = var.network_bridge
  ip_address     = "${var.worker_ips[count.index]}${var.ip_cidr}"
  gateway        = var.ip_gateway
  ssh_public_key = var.ssh_public_key
}

# Install K3s on control plane
resource "null_resource" "install_k3s_control_plane" {
  count = var.control_plane_count

  depends_on = [
    module.control_plane,
    null_resource.stop_docker_hosts  # Wait for Docker VMs to be stopped
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.control_plane[count.index].ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server --token='${local.k3s_token}' --cluster-init --tls-san=${module.control_plane[count.index].ip_address}",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}

# Install K3s on workers
resource "null_resource" "install_k3s_workers" {
  count = var.worker_count

  depends_on = [
    module.workers,
    null_resource.install_k3s_control_plane,
    null_resource.stop_docker_hosts  # Wait for Docker VMs to be stopped
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.workers[count.index].ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_URL='https://${module.control_plane[0].ip_address}:6443' K3S_TOKEN='${local.k3s_token}' sh -"
    ]
  }
}
