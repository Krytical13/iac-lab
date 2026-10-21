# vault/policies/admin.hcl — the named operator (Vault guide, Module 03).
# Everything the guide does after Module 03 runs under this policy, not root,
# so each path below is one the guide exercised. "sudo" is required on the
# paths Vault marks root-protected (audit devices, auth mounts, raft).

# Secrets engines used by the lab
path "secret/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
path "ssh-client-signer/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "ssh-host-signer/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "pki*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Mount management. "sys/mounts/*" does not match "sys/mounts" itself, which
# `vault secrets list` reads, so both forms are listed.
path "sys/mounts" {
  capabilities = ["read", "list"]
}
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/auth" {
  capabilities = ["read", "list"]
}
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/policies/acl" {
  capabilities = ["read", "list"]
}
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Auth methods (userpass users, AppRole roles, token lookups and revocation)
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Audit devices
path "sys/audit*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Leases (renew, revoke, inspect)
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Raft snapshots (Module 09). Missing from most "admin" examples, and the reason
# backups fail the day after root is revoked.
path "sys/storage/raft/*" {
  capabilities = ["read", "update", "sudo"]
}

# Health, metrics, seal status
path "sys/health" {
  capabilities = ["read", "sudo"]
}
path "sys/metrics" {
  capabilities = ["read"]
}
path "sys/seal-status" {
  capabilities = ["read"]
}
