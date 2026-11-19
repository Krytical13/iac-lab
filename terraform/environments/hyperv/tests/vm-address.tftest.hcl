# tests/vm-address.tftest.hcl — the module's ip output once a guest has reported in
#
# This mock answers the way a host does when the guest is up: a real guest
# reports its IPv6 link-local address as well as its IPv4 address, and the
# module's ip output has to pick the IPv4 one. It lives in its own file because
# run blocks in one file share state: a VM "created" by an earlier run block
# would keep the empty address list it was created with.
mock_provider "hyperv" {
  mock_resource "hyperv_machine_instance" {
    defaults = {
      network_adaptors = {
        ip_addresses = ["fe80::215:5dff:fe00:101", "192.168.1.101"]
      }
    }
  }
}

variables {
  vm_name     = "test-vm-01"
  source_vhdx = "C:\\HyperV\\Images\\golden.vhdx"
  seed_iso    = "C:\\HyperV\\Images\\seeds\\test-vm-01-seed.iso"
  switch_name = "Lab-External"
  vhd_path    = "C:\\HyperV\\VHDs"
  vm_path     = "C:\\HyperV\\VMs"
}

run "ip_is_the_first_ipv4_address" {
  command = apply

  module {
    source = "../../modules/hyperv-vm"
  }

  assert {
    condition     = output.ip == "192.168.1.101"
    error_message = "The ip output must skip IPv6 and return the first IPv4 address."
  }
}
