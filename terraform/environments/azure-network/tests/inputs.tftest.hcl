# tests/inputs.tftest.hcl: the input rules refuse bad values before a plan is made
#
# expect_failures turns a refusal into a pass: the run fails only if the bad
# value gets through.
mock_provider "azurerm" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "rejects_a_subscription_name" {
  command = plan

  variables {
    subscription_id = "Pay-As-You-Go"
  }

  expect_failures = [var.subscription_id]
}

run "rejects_a_public_address_space" {
  command = plan

  variables {
    address_space = "11.0.0.0/16"
  }

  expect_failures = [var.address_space]
}

run "rejects_a_network_that_is_not_a_16" {
  command = plan

  variables {
    address_space = "10.20.0.0/24"
  }

  expect_failures = [var.address_space]
}

run "rejects_a_port_out_of_range" {
  command = plan

  variables {
    data_port = 70000
  }

  expect_failures = [var.data_port]
}
