# pipeline/imports.tf: import blocks for the pipeline, and only for the pipeline
#
# Terraform does not read this folder: a root module is the .tf files of one
# directory. The workflow .github/workflows/azure-plan.yml copies this file one
# level up before it plans. Do not copy it there yourself: with these blocks in
# place the unit tests stop ("Cannot import resources from mock providers").
#
# Why the pipeline needs them. It has no state file: the state of this layer
# lives where the layer was applied. An import block tells Terraform which
# object in Azure belongs to which resource in the code, so a plan that starts
# from an empty state can still compare the two. The job only plans. Nothing
# is imported for good, and the runner is thrown away after the job.
#
# One block for each resource in ../network.tf. tests/tf-imports.sh checks that.
locals {
  import_base = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network"
}

import {
  to = azurerm_virtual_network.lab
  id = "${local.import_base}/virtualNetworks/${var.vnet_name}"
}

import {
  for_each = local.subnets
  to       = azurerm_subnet.lab[each.key]
  id       = "${local.import_base}/virtualNetworks/${var.vnet_name}/subnets/snet-${each.key}"
}

import {
  to = azurerm_network_security_group.lab
  id = "${local.import_base}/networkSecurityGroups/nsg-iac-lab"
}

import {
  to = azurerm_network_security_rule.allow_app_to_data
  id = "${local.import_base}/networkSecurityGroups/nsg-iac-lab/securityRules/AllowAppToData"
}

import {
  to = azurerm_network_security_rule.deny_vnet_inbound
  id = "${local.import_base}/networkSecurityGroups/nsg-iac-lab/securityRules/DenyVnetInbound"
}

# The import ID of an association is the ID of its subnet.
import {
  for_each = local.subnets
  to       = azurerm_subnet_network_security_group_association.lab[each.key]
  id       = "${local.import_base}/virtualNetworks/${var.vnet_name}/subnets/snet-${each.key}"
}
