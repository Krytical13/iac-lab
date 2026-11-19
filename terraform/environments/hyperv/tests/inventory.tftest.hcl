# tests/inventory.tftest.hcl — the environment: input validation and the Ansible inventory
#
# Both providers are mocked, so nothing is created on a host and no hosts.yml is
# written. override_module replaces each VM module with fixed outputs: the tests
# below are about what the environment does with the VMs' addresses, and the
# module has its own tests.
#
# The two inventory run blocks use command = apply, against the mocks. A plan
# would do for the three VMs overridden here, but a VM you add later has no
# override: at plan time its address is "known after apply", and every assertion
# that touches the inventory would stop with "Unknown condition value". Applied
# against the mock, the new VM simply has no address yet and is left out.
mock_provider "hyperv" {}
mock_provider "local" {}

variables {
  # 192.0.2.0/24 is reserved for documentation (RFC 5737): if a mock were ever
  # removed by mistake, this address still could not reach a real machine.
  hyperv_host     = "192.0.2.10"
  hyperv_user     = "nobody"
  hyperv_password = "not-a-real-password"
  host_nic        = "Ethernet"
}

override_module {
  target = module.ubuntu_lab_01
  outputs = {
    name = "ubuntu-lab-01"
    ip   = "192.168.1.101"
  }
}

override_module {
  target = module.rocky_lab_01
  outputs = {
    name = "rocky-lab-01"
    ip   = "192.168.1.102"
  }
}

# A VM that is still booting: the module returns a null ip until the guest reports one.
override_module {
  target = module.vault_lab_01
  outputs = {
    name = "vault-lab-01"
    ip   = null
  }
}

run "inventory_lists_only_vms_that_have_an_address" {
  command = apply

  assert {
    condition     = output.vm_ips == { "rocky-lab-01" = "192.168.1.102", "ubuntu-lab-01" = "192.168.1.101" }
    error_message = "vm_ips must hold the two VMs that reported an address and leave out the one that has not."
  }

  assert {
    condition     = strcontains(local_file.ansible_inventory.content, "ubuntu-lab-01:\n          ansible_host: 192.168.1.101")
    error_message = "The inventory must give ubuntu-lab-01 its reported address as ansible_host."
  }

  assert {
    condition     = !strcontains(local_file.ansible_inventory.content, "vault-lab-01")
    error_message = "A VM with no address yet must not appear in the inventory."
  }
}

run "lab_network_is_the_24_the_vms_sit_in" {
  command = apply

  assert {
    condition     = local.lab_network == "192.168.1.0/24"
    error_message = "lab_network must be the /24 of the VMs' addresses: the firewall rules use it as their source."
  }

  assert {
    condition     = strcontains(local_file.ansible_inventory.content, "lab_network: 192.168.1.0/24")
    error_message = "The inventory must hand lab_network to Ansible."
  }
}

run "a_host_name_with_a_space_is_rejected" {
  command = plan

  variables {
    hyperv_host = "hyperv host"
  }

  expect_failures = [var.hyperv_host]
}

run "an_empty_adapter_name_is_rejected" {
  command = plan

  variables {
    host_nic = ""
  }

  expect_failures = [var.host_nic]
}
