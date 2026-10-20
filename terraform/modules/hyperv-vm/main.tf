# modules/hyperv-vm/main.tf — Reusable VM module
# Creates a Hyper-V VM from a golden VHDX image

resource "null_resource" "copy_vhdx" {
  triggers = {
    vm_name = var.vm_name
  }

  provisioner "remote-exec" {
    inline = [
      "Copy-Item '${var.source_vhdx}' '${var.vhd_path}\\${var.vm_name}.vhdx'"
    ]

    connection {
      type     = "winrm"
      host     = var.hyperv_host
      user     = var.hyperv_user
      password = var.hyperv_password
      https    = true
      insecure = true
    }
  }
}

resource "hyperv_machine_instance" "vm" {
  name                   = var.vm_name
  generation             = 2
  memory_startup_bytes   = var.memory_mb * 1024 * 1024
  processor_count        = var.cpu_count
  state                  = "Running"
  wait_for_state_timeout = 120

  vm_firmware {
    enable_secure_boot = "Off" # Required for Linux cloud images
  }

  hard_disk_drives {
    path                = "${var.vhd_path}\\${var.vm_name}.vhdx"
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
  }

  network_adaptors {
    name        = "eth0"
    switch_name = var.switch_name
  }

  depends_on = [null_resource.copy_vhdx]
}