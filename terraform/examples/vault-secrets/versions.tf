# terraform/examples/vault-secrets — Terraform reading from the lab's Vault
# (Vault guide, Module 08). A root module of its own: it needs the Vault
# modules done, nothing from Hyper-V. Address, token and CA come from the
# environment (VAULT_ADDR, VAULT_TOKEN or ~/.vault-token, VAULT_CACERT).
terraform {
  required_version = ">= 1.11.0" # ephemeral resources and write-only arguments

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "vault" {
  # Nothing here on purpose: a token in a .tf file is a token in git.
}
