# tests/inputs.tftest.hcl: the input rules refuse bad values before a plan is made
#
# expect_failures turns a refusal into a pass: the run fails only if the bad
# value gets through.
#
# The resource group gets a real ID here as well. The role assignment checks the
# shape of its scope while the plan is made, and a made-up ID would fail there
# before the input rule under test is reached.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab"
      location = "eastus"
    }
  }
}

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  github_repository = "octo-org/octo-repo"
}

run "rejects_a_subscription_name" {
  command = plan

  variables {
    subscription_id = "Pay-As-You-Go"
  }

  expect_failures = [var.subscription_id]
}

run "rejects_a_repository_without_an_owner" {
  command = plan

  variables {
    github_repository = "octo-repo"
  }

  expect_failures = [var.github_repository]
}

run "rejects_a_wildcard_repository" {
  command = plan

  variables {
    github_repository = "octo-org/*"
  }

  expect_failures = [var.github_repository]
}

run "rejects_a_repository_url" {
  command = plan

  variables {
    github_repository = "https://github.com/octo-org/octo-repo"
  }

  expect_failures = [var.github_repository]
}

run "rejects_an_environment_with_a_space" {
  command = plan

  variables {
    github_environment = "azure lab"
  }

  expect_failures = [var.github_environment]
}

run "rejects_an_environment_in_capitals" {
  command = plan

  variables {
    github_environment = "Production"
  }

  expect_failures = [var.github_environment]
}

run "rejects_an_empty_environment" {
  command = plan

  variables {
    github_environment = ""
  }

  expect_failures = [var.github_environment]
}
