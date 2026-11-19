# tests/vm-module.tftest.hcl — unit tests for modules/hyperv-vm
#
# mock_provider replaces the real Hyper-V provider with a stand-in that accepts
# any configuration and makes up the values a real host would report. No WinRM
# connection is opened and no credentials are needed, so these tests run anywhere
# Terraform runs: your laptop, a CI runner, a machine with no Hyper-V host at all.
mock_provider "hyperv" {}

variables {
  # Inputs of modules/hyperv-vm. Every run block below loads that module directly
  # (the module block), so the environment's own variables are not needed here.
  vm_name     = "test-vm-01"
  source_vhdx = "C:\\HyperV\\Images\\golden.vhdx"
  seed_iso    = "C:\\HyperV\\Images\\seeds\\test-vm-01-seed.iso"
  switch_name = "Lab-External"
  vhd_path    = "C:\\HyperV\\VHDs"
  vm_path     = "C:\\HyperV\\VMs"
}

run "defaults_are_2_gb_and_2_cpus" {
  command = plan

  module {
    source = "../../modules/hyperv-vm"
  }

  assert {
    condition     = hyperv_machine_instance.vm.memory_startup_bytes == 2147483648
    error_message = "memory_mb = 2048 must reach Hyper-V as 2147483648 bytes (2048 x 1024 x 1024)."
  }

  assert {
    condition     = hyperv_machine_instance.vm.processor_count == 2
    error_message = "The default VM has 2 virtual CPUs."
  }
}

run "disk_is_named_after_the_vm" {
  command = plan

  module {
    source = "../../modules/hyperv-vm"
  }

  assert {
    condition     = hyperv_vhd.disk.path == "C:\\HyperV\\VHDs\\test-vm-01.vhdx"
    error_message = "The disk file is <vhd_path>\\<vm_name>.vhdx."
  }

  assert {
    condition     = hyperv_vhd.disk.source == "C:\\HyperV\\Images\\golden.vhdx"
    error_message = "The disk is copied from the golden image passed in source_vhdx."
  }
}

run "a_bigger_vm_gets_what_it_asked_for" {
  command = plan

  module {
    source = "../../modules/hyperv-vm"
  }

  variables {
    memory_mb = 4096
    cpu_count = 4
  }

  assert {
    condition     = hyperv_machine_instance.vm.memory_startup_bytes == 4294967296
    error_message = "memory_mb = 4096 must reach Hyper-V as 4294967296 bytes."
  }

  assert {
    condition     = hyperv_machine_instance.vm.processor_count == 4
    error_message = "cpu_count must be passed through unchanged."
  }
}

run "boots_from_disk_before_the_seed_and_the_network" {
  command = plan

  module {
    source = "../../modules/hyperv-vm"
  }

  assert {
    condition     = [for b in hyperv_machine_instance.vm.vm_firmware[0].boot_order : b.boot_type] == ["HardDiskDrive", "DvdDrive", "NetworkAdapter"]
    error_message = "Boot order must be disk, seed ISO, network: Hyper-V's default tries PXE first."
  }

  assert {
    condition     = hyperv_machine_instance.vm.checkpoint_type == "Disabled"
    error_message = "Automatic checkpoints stay off: lab VMs are rebuilt from the golden image."
  }
}

run "ip_is_null_until_the_guest_reports_one" {
  command = apply

  module {
    source = "../../modules/hyperv-vm"
  }

  assert {
    condition     = output.ip == null
    error_message = "With no address reported, the ip output must be null (the inventory skips such a VM)."
  }
}
