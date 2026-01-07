output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = [for node in module.control_plane : node.ip_address]
}

output "worker_ips" {
  description = "IP addresses of worker nodes"
  value       = [for node in module.workers : node.ip_address]
}

output "k3s_token" {
  description = "K3s cluster token"
  value       = local.k3s_token
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = "ssh ubuntu@${module.control_plane[0].ip_address} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "cluster_endpoint" {
  description = "K3s cluster endpoint"
  value       = "https://${module.control_plane[0].ip_address}:6443"
}

output "ssh_control_plane" {
  description = "SSH command for control plane"
  value       = "ssh ubuntu@${module.control_plane[0].ip_address}"
}

output "ssh_workers" {
  description = "SSH commands for worker nodes"
  value       = [for node in module.workers : "ssh ubuntu@${node.ip_address}"]
}
