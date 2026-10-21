# vault/agent/agent.hcl — Vault Agent for a machine that needs a TLS certificate
# (Vault guide, Module 06). Start it from the vault/ directory:
#   vault agent -config=agent/agent.hcl
# The server address and CA come from VAULT_ADDR and VAULT_CACERT in your shell,
# like the CLI; a `vault { address = "..." }` block would pin them here instead.
# Paths are relative to the directory the agent is started from.

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "local/agent/role-id"
      secret_id_file_path = "local/agent/secret-id"
      # Default is true: the agent deletes the secret-id file after reading it,
      # so a restart has nothing to log in with. Right for a pipeline that
      # delivers a fresh (response-wrapped) secret ID on every start; wrong for
      # a lab, where the files are the delivery.
      remove_secret_id_file_after_reading = false
    }
  }

  # The token the agent obtains, for other tools on this machine.
  sink "file" {
    config = {
      path = "local/agent/token"
    }
  }
}

# One template produces the certificate chain; writeToFile inside it produces
# the key. Two templates (cert.tpl + key.tpl) would call pki_int/issue twice and
# hand you a key that does not match the certificate.
template {
  source      = "agent/cert.tpl"
  destination = "local/agent/tls.crt"
  perms       = "0644"
  # command = "systemctl reload myapp"   # when a service should pick the new cert up
}

template_config {
  exit_on_retry_failure = true   # fail loudly instead of retrying forever
}
