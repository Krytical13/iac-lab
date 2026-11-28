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
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  github_subject_prefix = "repo:octo-org@123456/octo-repo@456789"
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
    github_subject_prefix = "repo:octo-repo@456789"
  }

  expect_failures = [var.github_subject_prefix]
}

run "rejects_a_wildcard_repository" {
  command = plan

  variables {
    github_subject_prefix = "repo:octo-org/*"
  }

  expect_failures = [var.github_subject_prefix]
}

run "rejects_a_repository_url" {
  command = plan

  variables {
    github_subject_prefix = "https://github.com/octo-org/octo-repo"
  }

  expect_failures = [var.github_subject_prefix]
}

# The two names alone are not what GitHub reports: its answer starts with repo:
run "rejects_a_name_without_the_repo_prefix" {
  command = plan

  variables {
    github_subject_prefix = "octo-org/octo-repo"
  }

  expect_failures = [var.github_subject_prefix]
}

# GitHub writes both IDs or none. One of the two is a copying mistake.
run "rejects_a_prefix_with_one_id_missing" {
  command = plan

  variables {
    github_subject_prefix = "repo:octo-org@123456/octo-repo"
  }

  expect_failures = [var.github_subject_prefix]
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
