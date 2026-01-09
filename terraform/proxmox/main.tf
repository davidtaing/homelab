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

  vm_name        = "k3s-control-${count.index + 1}"
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

  vm_name        = "k3s-worker-${count.index + 1}"
  vm_id          = 210 + count.index
  target_node    = var.proxmox_nodes[(count.index + 1) % length(var.proxmox_nodes)]
  template_name  = var.vm_template_name
  cpu_cores      = var.vm_cpu_cores
  memory         = var.vm_memory
  disk_size      = var.vm_disk_size
  network_bridge = var.network_bridge
  ip_address     = "${var.worker_ips[count.index]}${var.ip_cidr}"
  gateway        = var.ip_gateway
  ssh_public_key = var.ssh_public_key
}

# Install K3s on first control plane node (cluster init)
resource "null_resource" "install_k3s_control_plane_first" {
  count = var.control_plane_count > 0 ? 1 : 0

  depends_on = [module.control_plane]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.control_plane[0].ip_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Installing K3s on first control plane (cluster init)...'",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server --token='${local.k3s_token}' --cluster-init --tls-san=${module.control_plane[0].ip_address}",
      "echo 'Setting kubeconfig permissions...'",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml",
      "echo 'Waiting for K3s to be ready...'",
      "timeout 60 bash -c 'until sudo kubectl get nodes >/dev/null 2>&1; do sleep 2; done' || true",
      "echo 'First control plane node ready!'"
    ]
  }

  triggers = {
    vm_id = module.control_plane[0].vm_id
  }
}

# Install K3s on additional control plane nodes (join existing cluster)
resource "null_resource" "install_k3s_control_plane_additional" {
  count = var.control_plane_count > 1 ? var.control_plane_count - 1 : 0

  depends_on = [
    module.control_plane,
    null_resource.install_k3s_control_plane_first
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.control_plane[count.index + 1].ip_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Installing K3s on additional control plane node...'",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server --token='${local.k3s_token}' --server https://${module.control_plane[0].ip_address}:6443 --tls-san=${module.control_plane[count.index + 1].ip_address}",
      "echo 'Setting kubeconfig permissions...'",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml",
      "echo 'Additional control plane node ready!'"
    ]
  }

  triggers = {
    vm_id = module.control_plane[count.index + 1].vm_id
  }
}

# Install K3s on workers
resource "null_resource" "install_k3s_workers" {
  count = var.worker_count

  depends_on = [
    module.workers,
    null_resource.install_k3s_control_plane_first,
    null_resource.install_k3s_control_plane_additional
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = module.workers[count.index].ip_address
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Installing K3s agent on worker node...'",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_URL='https://${module.control_plane[0].ip_address}:6443' K3S_TOKEN='${local.k3s_token}' sh -",
      "echo 'Waiting for K3s agent to be ready...'",
      "timeout 30 bash -c 'until systemctl is-active --quiet k3s-agent; do sleep 2; done' || true",
      "echo 'Worker node ready!'"
    ]
  }

  triggers = {
    vm_id = module.workers[count.index].vm_id
  }
}
