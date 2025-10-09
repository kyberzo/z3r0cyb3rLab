# Provider configuration
# https://registry.terraform.io/providers/Telmate/proxmox/latest
terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  # set in vars.tf 
  pm_api_url = var.pm_api_url

  # insecure unless using signed certificates
  pm_tls_insecure = true

  # token details
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret

}

#------------------------------------------------------------------------------------------
# K8s Master Node
#------------------------------------------------------------------------------------------
resource "proxmox_vm_qemu" "k8s-master" {
  count = 1
  name = "k8s-master"
  description = "K8s Master"
  target_node = "pve"
  # Change the VM template name accordingly
  clone = "ubuntu-server2404-kubernetes-template"
  os_type = "cloud-init"
  boot = "order=scsi0"
  memory = 4096
  # Activate QEMU agent for this VM
  agent = 1
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"

  cpu { 
    cores = 2
    sockets = 1
  }
  
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size            = 32
          #cache           = ""
          storage         = "local-lvm"
          replicate       = false
          # ssd_emulation is currently not supported in terraform provider
          # by practice this is usually combined with discard option
          #ssd_emulation   = true
          #discard         = true
        }
      }
    }
  }

  network {
    id = 0
    model = "virtio"
    bridge = "vmbr0"
  }

  serial {
    id   = 0
    type = "socket"
  }

  # Change the VMID, I practice to use the VMID as the last octet of the IP address
  vmid = 130

  # Change Accordingly
  # cloud init network configuration
  # note that proxmox will automatically set the DNS to the one defined in the host
  ipconfig0 = "ip=192.168.200.130/24,gw=192.168.200.1"
  
  # Note: The template usually works, this is just for consistency.
  # cloud-init user and password
  ciuser = var.ssh_user
  cipassword = var.ssh_password

  sshkeys = <<EOF
    <ssh_public_key_contents>
    EOF


  provisioner "remote-exec" {
    inline = ["echo ${var.ssh_password} | sudo -S -k hostnamectl set-hostname k8s-master"]

    connection {
      host = self.ssh_host
      type = "ssh"
      user = var.ssh_user
      password = var.ssh_password
      private_key = "${file("../../mylabskey")}"
    }
  }
}

#------------------------------------------------------------------------------------------
# Worker Nodes
#------------------------------------------------------------------------------------------
resource "proxmox_vm_qemu" "k8s-node" {
  count = 3 # number of VMs to create
  name = "k8s-node${count.index + 1}"
  description = "K8s node"
  target_node = "pve" 
  # Change the VM template name accordingly
  clone = "ubuntu-server2404-kubernetes-template"
  os_type = "cloud-init"
  boot = "order=scsi0"
  memory = 2048 
  # Activate QEMU agent for this VM
  agent = 1
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  
  # note that cores, sockets and memory settings are not copied from the source VM template
  cpu { 
    cores = 1
    sockets = 1
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size            = 32
          #cache           = ""
          storage         = "local-lvm"
          replicate       = false
          # ssd_emulation is currently not supported in terraform provider
          # by practice this is usually combined with discard option
          #ssd_emulation   = true
          #discard         = true
        }
      }
    }
  }

  network {
    id = 0
    model = "virtio"
    bridge = "vmbr0"
  }
  serial {
    id   = 0
    type = "socket"
  }

  # Change the Values accordingly, I practice to use the VMID as the last octet of the IP address
  # note that count.index starts from 0, so we add 131 to start from
  ipconfig0 = "ip=192.168.200.${count.index + 131 }/24,gw=192.168.200.1"
  vmid = "${count.index + 131 }"

  # Note: The template usually works, this is just for consistency.
  ciuser = var.ssh_user
  cipassword = var.ssh_password

  sshkeys = <<EOF
    <ssh_public_key_contents>
    EOF

  provisioner "remote-exec" {
    inline = ["echo ${var.ssh_password} | sudo -S -k hostnamectl set-hostname ${self.name}"]

    connection {
      host = self.ssh_host
      type = "ssh"
      user = var.ssh_user
      password = var.ssh_password
      private_key = "${file("../../mylabskey")}"
    }
  } 
}

#------------------------------------------------------------------------------------------
output "proxmox_master_default_ip_addresses" {
  description = "Current IP Default"
  value = proxmox_vm_qemu.k8s-master.*.default_ipv4_address
}

output "proxmox_nodes_default_ip_addresses" {
  description = "Current IP Default"
  value = proxmox_vm_qemu.k8s-node.*.default_ipv4_address
}