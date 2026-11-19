# network.tf: the first resources that live inside the guardrails.
#
#   1. the resource provider Microsoft.Network, registered where a plan shows it
#   2. one virtual network with two subnets, app and data
#   3. one network security group on both subnets, with two rules
#
# The lab found no charge for any of this. What bills is what gets put into a
# network later: machines, disks, public addresses, gateways.

locals {
  # The address plan. Each subnet is a /24 cut out of the /16 by number, so two
  # subnets cannot overlap and nobody does the arithmetic by hand.
  subnets = {
    app  = cidrsubnet(var.address_space, 8, 1)
    data = cidrsubnet(var.address_space, 8, 2)
  }
}

resource "azurerm_resource_provider_registration" "network" {
  count = var.register_network_provider ? 1 : 0

  name = "Microsoft.Network"
}

resource "azurerm_virtual_network" "lab" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  address_space       = [var.address_space]
  tags                = var.tags

  # Azure refuses a network on a subscription where the resource provider is
  # not registered, so the registration comes first.
  depends_on = [azurerm_resource_provider_registration.network]
}

resource "azurerm_subnet" "lab" {
  for_each = local.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [each.value]

  # A private subnet: nothing in it reaches the internet until someone adds an
  # explicit way out.
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-iac-lab"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  tags                = var.tags

  depends_on = [azurerm_resource_provider_registration.network]
}

# A network security group with no rules of its own lets every address in the
# virtual network reach every other one. The two rules below close that. Rules
# are read in order of priority, lowest number first, and the first match wins.

resource "azurerm_network_security_rule" "allow_app_to_data" {
  name                        = "AllowAppToData"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = local.subnets.app
  source_port_range           = "*"
  destination_address_prefix  = local.subnets.data
  destination_port_range      = tostring(var.data_port)
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.lab.name
}

resource "azurerm_network_security_rule" "deny_vnet_inbound" {
  name                        = "DenyVnetInbound"
  priority                    = 4096 # the last number a rule of your own can have
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "*"
  resource_group_name         = data.azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.lab.name
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  for_each = azurerm_subnet.lab

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.lab.id
}
