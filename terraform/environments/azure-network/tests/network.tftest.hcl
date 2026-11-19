# tests/network.tftest.hcl: what the network layer is made of
#
# The azurerm provider is mocked, so this needs no Azure account and no sign-in,
# and it creates nothing. A mocked provider makes up values for anything Azure
# would answer. Two kinds of values get a real shape below: the resource group
# this layer reads, and the IDs that other resources check before they accept
# them.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab"
      location = "eastus"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab/providers/Microsoft.Network/virtualNetworks/vnet-iac-lab/subnets/snet-mock"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab/providers/Microsoft.Network/networkSecurityGroups/nsg-iac-lab"
    }
  }
}

variables {
  subscription_id           = "00000000-0000-0000-0000-000000000000"
  register_network_provider = true
}

run "network_goes_into_the_group_it_reads" {
  command = apply

  assert {
    condition     = azurerm_virtual_network.lab.resource_group_name == "rg-iac-lab"
    error_message = "The network must go into the resource group named by var.resource_group_name."
  }

  assert {
    condition     = azurerm_virtual_network.lab.location == "eastus"
    error_message = "The network must take its region from the resource group, not from a value of its own."
  }

  assert {
    condition     = azurerm_virtual_network.lab.tags["managed_by"] == "terraform"
    error_message = "The network must carry the managed_by tag, so nobody edits it by hand."
  }
}

run "subnets_are_cut_from_the_address_space" {
  command = apply

  assert {
    condition     = one(azurerm_subnet.lab["app"].address_prefixes) == "10.20.1.0/24"
    error_message = "The app subnet must be the /24 with number 1 inside the address space."
  }

  assert {
    condition     = one(azurerm_subnet.lab["data"].address_prefixes) == "10.20.2.0/24"
    error_message = "The data subnet must be the /24 with number 2 inside the address space."
  }
}

run "address_plan_follows_a_new_address_space" {
  command = apply

  variables {
    address_space = "172.24.0.0/16"
  }

  assert {
    condition     = output.subnets == { "snet-app" = "172.24.1.0/24", "snet-data" = "172.24.2.0/24" }
    error_message = "Changing var.address_space must move both subnets with it."
  }
}

run "subnets_are_private" {
  command = apply

  assert {
    condition     = alltrue([for s in azurerm_subnet.lab : s.default_outbound_access_enabled == false])
    error_message = "No subnet may keep Azure's default way out to the internet."
  }
}

run "every_subnet_gets_the_security_group" {
  command = apply

  assert {
    condition     = keys(azurerm_subnet_network_security_group_association.lab) == keys(azurerm_subnet.lab)
    error_message = "There must be one association for each subnet."
  }

  assert {
    condition     = alltrue([for a in azurerm_subnet_network_security_group_association.lab : a.network_security_group_id == azurerm_network_security_group.lab.id])
    error_message = "Every subnet must be tied to the lab network security group."
  }
}

run "only_app_reaches_data_and_on_one_port" {
  command = apply

  assert {
    condition     = azurerm_network_security_rule.allow_app_to_data.source_address_prefix == "10.20.1.0/24"
    error_message = "The allow rule must only let the app subnet in."
  }

  assert {
    condition     = azurerm_network_security_rule.allow_app_to_data.destination_address_prefix == "10.20.2.0/24"
    error_message = "The allow rule must only lead to the data subnet."
  }

  assert {
    condition     = azurerm_network_security_rule.allow_app_to_data.destination_port_range == "5432" && azurerm_network_security_rule.allow_app_to_data.protocol == "Tcp"
    error_message = "The allow rule must open the one TCP port in var.data_port and nothing else."
  }
}

run "everything_else_inside_the_network_is_denied" {
  command = apply

  assert {
    condition     = azurerm_network_security_rule.deny_vnet_inbound.access == "Deny" && azurerm_network_security_rule.deny_vnet_inbound.source_address_prefix == "VirtualNetwork"
    error_message = "The last rule must deny what comes from inside the virtual network."
  }

  assert {
    condition     = azurerm_network_security_rule.allow_app_to_data.priority < azurerm_network_security_rule.deny_vnet_inbound.priority
    error_message = "The allow rule must be read before the deny rule: a lower priority number."
  }
}

run "provider_is_registered_when_asked" {
  command = apply

  assert {
    condition     = length(azurerm_resource_provider_registration.network) == 1 && azurerm_resource_provider_registration.network[0].name == "Microsoft.Network"
    error_message = "With register_network_provider = true the code must register Microsoft.Network, and only that."
  }
}

run "provider_is_left_alone_when_already_registered" {
  command = apply

  variables {
    register_network_provider = false
  }

  assert {
    condition     = length(azurerm_resource_provider_registration.network) == 0
    error_message = "With register_network_provider = false the code must not touch the registration."
  }
}
