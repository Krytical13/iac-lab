# guardrails.tf: one resource group, and three things that keep it free.
#
#   1. a policy that only lets no-cost resource types in
#   2. a policy that only lets the chosen regions in
#   3. a budget that sends mail on the first cent
#
# The policies block. The budget only warns: Azure does not stop anything when
# a budget is passed. That is why the policies come first.

locals {
  # Built-in policy definitions. Their IDs are the same in every tenant.
  policy_allowed_resource_types = "/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c"
  policy_allowed_locations      = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  allowed_locations = length(var.allowed_locations) > 0 ? var.allowed_locations : [var.location]
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group_policy_assignment" "allowed_resource_types" {
  name                 = "lab-allowed-resource-types"
  display_name         = "Lab: only no-cost resource types"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = local.policy_allowed_resource_types

  parameters = jsonencode({
    listOfResourceTypesAllowed = { value = var.allowed_resource_types }
    effect                     = { value = var.policy_effect }
  })
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "lab-allowed-locations"
  display_name         = "Lab: only the chosen regions"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = local.policy_allowed_locations

  parameters = jsonencode({
    listOfAllowedLocations = { value = local.allowed_locations }
    effect                 = { value = var.policy_effect }
  })
}

resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-${var.resource_group_name}"
  resource_group_id = azurerm_resource_group.lab.id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  # Mail as soon as real spend passes 1 % of the budget: with the default
  # budget of 1, that is the first cent.
  notification {
    enabled        = true
    threshold      = 1
    threshold_type = "Actual"
    operator       = "GreaterThan"
    contact_emails = var.alert_emails
  }
}
