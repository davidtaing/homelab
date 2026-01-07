# Proxmox Setup Guide

This directory contains guides for setting up Proxmox VE on your homelab servers.

## Setup Order

Follow these guides in sequence:

1. [01-installation.md](01-installation.md) - Install Proxmox VE on both servers
2. [02-initial-config.md](02-initial-config.md) - Initial configuration and networking
3. [03-clustering.md](03-clustering.md) - Connect both nodes into a cluster
4. [04-terraform-prep.md](04-terraform-prep.md) - Prepare for Terraform automation
5. [05-cloud-init-template.md](05-cloud-init-template.md) - Create Ubuntu cloud-init template

## What Gets Automated vs Manual

### Manual Setup (One-Time)
- ❌ Install Proxmox OS on physical servers
- ❌ Configure Proxmox networking
- ❌ Create Proxmox cluster
- ❌ Create Terraform API user/token
- ❌ Create Ubuntu cloud-init template

### Automated by Terraform
- ✅ Create VMs from template
- ✅ Configure VM resources (CPU, RAM, disk)
- ✅ Assign static IPs
- ✅ Install k3s on all nodes
- ✅ Join workers to control plane
- ✅ Everything inside the VMs

### Manual After Terraform (Optional)
- ❌ Get kubeconfig from control plane
- ❌ Install kubectl locally
- ❌ Deploy applications to Kubernetes

## Quick Reference

**Proxmox Web UI**: `https://<proxmox-ip>:8006`
**Default Login**: `root` + password you set during install
**SSH Access**: `ssh root@<proxmox-ip>`

## Hardware Requirements

- **Minimum**:
  - 8GB RAM per server
  - 100GB storage per server
  - 1 network interface

- **Your Setup** (Recommended):
  - 2 Proxmox servers
  - 256GB SSD each
  - Static IP addresses
  - Connected to same network

## Support

If you run into issues, check:
- [Proxmox Documentation](https://pve.proxmox.com/pve-docs/)
- [Proxmox Forum](https://forum.proxmox.com/)
- [r/Proxmox](https://reddit.com/r/Proxmox)
