provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_api_token_id = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret

  pm_tls_insecure = var.proxmox_tls_insecure
  pm_parallel     = 2
  pm_timeout      = 600
}
