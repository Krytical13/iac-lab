# tests/inputs.tftest.hcl: wrong inputs are stopped before a plan is made
#
# Each run block hands the code one bad value and expects the named variable's
# validation to refuse it. These runs only plan, and the provider is mocked.
mock_provider "azurerm" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  alert_emails    = ["ops@example.com"]
}

run "rejects_a_subscription_name" {
  command = plan

  variables {
    subscription_id = "my-subscription"
  }

  expect_failures = [var.subscription_id]
}

run "rejects_an_empty_alert_list" {
  command = plan

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "rejects_a_type_that_bills" {
  command = plan

  variables {
    allowed_resource_types = ["Microsoft.Network/virtualNetworks", "Microsoft.Compute/virtualMachines"]
  }

  expect_failures = [var.allowed_resource_types]
}

run "rejects_an_unknown_policy_effect" {
  command = plan

  variables {
    policy_effect = "Block"
  }

  expect_failures = [var.policy_effect]
}

run "rejects_a_mid_month_budget_start" {
  command = plan

  variables {
    budget_start_date = "2026-11-15T00:00:00Z"
  }

  expect_failures = [var.budget_start_date]
}

run "rejects_a_zero_budget" {
  command = plan

  variables {
    budget_amount = 0
  }

  expect_failures = [var.budget_amount]
}
