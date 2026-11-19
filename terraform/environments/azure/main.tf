# main.tf: provider configuration for the Azure part of the lab
terraform {
  required_version = ">= 1.7.0" # the tests use mock_provider

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # By default the provider registers a long list of resource providers on the
  # subscription. That is a change this code never asked for, so it is switched
  # off.
  resource_provider_registrations = "none"
}
