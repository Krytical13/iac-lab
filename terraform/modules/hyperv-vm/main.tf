# modules/hyperv-vm/main.tf — one Linux VM from a golden cloud image
#
# 1. hyperv_vhd copies the golden VHDX to this VM's own disk file (the provider
#    runs Copy-Item on the host, so nothing is transferred from your machine).
# 2. hyperv_machine_instance builds a Generation 2 VM around that disk, attaches
#    the cloud-init seed ISO as a DVD, connects it to the switch, starts it and
#    waits until the guest reports an IP address through Hyper-V integration
#    services (the KVP daemon the seed installs).

resource "hyperv_vhd" "disk" {
  path   = "${var.vhd_path}\\${var.vm_name}.vhdx"
  source = var.source_vhdx
}

resource "hyperv_machine_instance" "vm" {
  name                   = var.vm_name
  path                   = var.vm_path
  smart_paging_file_path = var.vm_path
  snapshot_file_location = var.vm_path
  generation             = 2
  memory_startup_bytes   = var.memory_mb * 1024 * 1024
  static_memory          = true
  processor_count        = var.cpu_count
  state                  = "Running"

  wait_for_state_timeout = 120
  wait_for_ips_timeout   = 600 # first boot installs packages before the KVP daemon can report an IP: 3-5 min seen

  # Client Hyper-V takes an "Automatic Checkpoint" every time a VM starts, which turns
  # the disk into a .avhdx chain. Lab VMs are rebuilt from the golden image instead.
  checkpoint_type = "Disabled"

  # Hyper-V fills these blocks in on its own; naming them (with the provider's defaults)
  # keeps a second `terraform plan` at "No changes" instead of trying to null them out.
  vm_processor {}

  vm_firmware {
    # Off is simplest for cloud images; Ubuntu and Rocky also boot with Secure Boot
    # using the MicrosoftUEFICertificateAuthority template.
    enable_secure_boot = "Off"

    # Disk first, then the seed ISO, then PXE: Hyper-V's default tries the network first.
    boot_order {
      boot_type           = "HardDiskDrive"
      controller_number   = 0
      controller_location = 0
    }
    boot_order {
      boot_type           = "DvdDrive"
      controller_number   = 0
      controller_location = 1
    }
    boot_order {
      boot_type = "NetworkAdapter"
    }
  }

  hard_disk_drives {
    path                = hyperv_vhd.disk.path
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
  }

  dvd_drives {
    path                = var.seed_iso
    controller_number   = 0
    controller_location = 1
    resource_pool_name  = "Primordial" # what Hyper-V reports back; omitted, every plan tries to clear it
  }

  network_adaptors {
    name         = "eth0"
    switch_name  = var.switch_name
    wait_for_ips = true
  }
}
