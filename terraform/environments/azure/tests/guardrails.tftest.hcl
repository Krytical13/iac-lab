# tests/guardrails.tftest.hcl: what the guardrails are made of
#
# The azurerm provider is mocked, so this needs no Azure account and no sign-in,
# and it creates nothing. A mocked provider makes up values for anything Azure
# would compute. The resource group ID is given a real shape below because the
# other resources check that they are handed a valid resource group ID.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  alert_emails    = ["ops@example.com"]
}

run "resource_group_is_named_and_tagged" {
  command = apply

  assert {
    condition     = azurerm_resource_group.lab.name == "rg-iac-lab"
    error_message = "The resource group must take its name from var.resource_group_name."
  }

  assert {
    condition     = azurerm_resource_group.lab.tags["managed_by"] == "terraform"
    error_message = "The resource group must carry the managed_by tag, so nobody edits it by hand."
  }
}

run "type_policy_uses_the_built_in_definition" {
  command = apply

  assert {
    condition     = endswith(azurerm_resource_group_policy_assignment.allowed_resource_types.policy_definition_id, "/a08ec900-254a-4555-9bf5-e42af04b5c5c")
    error_message = "The assignment must point at the built-in 'Allowed resource types' definition."
  }

  assert {
    condition     = azurerm_resource_group_policy_assignment.allowed_resource_types.resource_group_id == azurerm_resource_group.lab.id
    error_message = "The policy must be assigned to the lab resource group and nowhere wider."
  }
}

run "type_policy_passes_the_list_through" {
  command = apply

  assert {
    # jsondecode returns a tuple and the variable is a list: tolist makes them comparable.
    condition = (
      tolist(jsondecode(azurerm_resource_group_policy_assignment.allowed_resource_types.parameters).listOfResourceTypesAllowed.value)
      == var.allowed_resource_types
    )
    error_message = "The policy parameter must be exactly var.allowed_resource_types."
  }

  assert {
    condition = alltrue([
      for t in jsondecode(azurerm_resource_group_policy_assignment.allowed_resource_types.parameters).listOfResourceTypesAllowed.value :
      !startswith(lower(t), "microsoft.compute/")
    ])
    error_message = "No Compute type may be on the default list: VMs and disks bill."
  }
}

run "location_policy_defaults_to_the_lab_region" {
  command = apply

  assert {
    condition = (
      jsondecode(azurerm_resource_group_policy_assignment.allowed_locations.parameters).listOfAllowedLocations.value
      == [var.location]
    )
    error_message = "With allowed_locations empty, the only region allowed must be var.location."
  }
}

run "location_policy_takes_an_explicit_list" {
  command = apply

  variables {
    allowed_locations = ["eastus", "eastus2"]
  }

  assert {
    condition     = output.allowed_locations == tolist(["eastus", "eastus2"])
    error_message = "A list in allowed_locations must replace the default."
  }
}

run "policies_deny_by_default" {
  command = apply

  assert {
    condition     = jsondecode(azurerm_resource_group_policy_assignment.allowed_resource_types.parameters).effect.value == "Deny"
    error_message = "The type policy must refuse by default, not only record."
  }

  assert {
    condition     = jsondecode(azurerm_resource_group_policy_assignment.allowed_locations.parameters).effect.value == "Deny"
    error_message = "The location policy must refuse by default, not only record."
  }
}

run "policies_can_be_switched_to_audit" {
  command = apply

  variables {
    policy_effect = "Audit"
  }

  assert {
    condition     = jsondecode(azurerm_resource_group_policy_assignment.allowed_resource_types.parameters).effect.value == "Audit"
    error_message = "policy_effect must reach the type policy."
  }

  assert {
    condition     = jsondecode(azurerm_resource_group_policy_assignment.allowed_locations.parameters).effect.value == "Audit"
    error_message = "policy_effect must reach the location policy."
  }
}

run "budget_mails_on_the_first_cent" {
  command = apply

  assert {
    condition     = azurerm_consumption_budget_resource_group.lab.amount == 1
    error_message = "The default budget is 1: a tripwire, not an allowance."
  }

  assert {
    condition     = one(azurerm_consumption_budget_resource_group.lab.notification).threshold == 1
    error_message = "The alert must fire at 1 % of the budget."
  }

  assert {
    condition     = one(azurerm_consumption_budget_resource_group.lab.notification).threshold_type == "Actual"
    error_message = "The alert must be on real spend, not on a forecast."
  }

  assert {
    condition     = tolist(one(azurerm_consumption_budget_resource_group.lab.notification).contact_emails) == tolist(["ops@example.com"])
    error_message = "The alert must go to the addresses in var.alert_emails."
  }
}
