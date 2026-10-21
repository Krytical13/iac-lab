# vault/policies/automation.hcl — what Ansible, Vault Agent and Terraform may do
# (Vault guide, Module 03). Attached to the AppRole "automation". Only what the
# lab's automation actually does; machines never sign user SSH keys.

# Read the lab's static secrets (KV v2: values under data/, versions under metadata/)
path "secret/data/homelab/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/homelab/*" {
  capabilities = ["read", "list"]
}

# Fetch the SSH user CA public key, to deploy it with the base role
path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}

# Issue TLS certificates for services (Vault Agent, Module 06)
path "pki_int/issue/homelab" {
  capabilities = ["create", "update"]
}
