resource "proxmox_vm_qemu" "k3s_node" {
  name        = var.vm_name
  target_node = var.target_node
  vmid        = var.vm_id

  clone = var.template_name

  agent    = 1
  os_type  = "cloud-init"
  memory   = var.memory
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  cpu {
    cores   = var.cpu_cores
    sockets = 1
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = var.disk_size
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  ipconfig0 = "ip=${var.ip_address},gw=${var.gateway}"

  nameserver = var.nameserver

  ciuser  = "ubuntu"
  sshkeys = var.ssh_public_key

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}
