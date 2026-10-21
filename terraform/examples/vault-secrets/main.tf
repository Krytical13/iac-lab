# main.tf — two ways to read the same secret, and where each one ends up.

# 1. A data source. Simple, and the value is written to terraform.tfstate in
#    clear text — that is how state works, not a Vault limitation.
data "vault_kv_secret_v2" "snmpd" {
  mount = "secret"
  name  = "homelab/snmpd"
}

output "community" {
  description = "The SNMP community string, from the data source (so: also in the state file)"
  value       = data.vault_kv_secret_v2.snmpd.data["community"]
  sensitive   = true
}

# 2. An ephemeral resource (Terraform 1.10+). Opened during plan and apply,
#    closed afterwards, never persisted. It can only feed places that are not
#    persisted either: provider configuration, provisioner connections, and
#    write-only arguments like the one below.
ephemeral "vault_kv_secret_v2" "snmpd" {
  mount = "secret"
  name  = "homelab/snmpd"
}

# A write-only argument (data_json_wo) sends the value to Vault and stores only
# the version number in state. The result is a second secret whose value never
# touched terraform.tfstate.
resource "vault_kv_secret_v2" "copy" {
  mount                = "secret"
  name                 = "homelab/snmpd-copy"
  data_json_wo         = jsonencode({ community = ephemeral.vault_kv_secret_v2.snmpd.data["community"] })
  data_json_wo_version = 1 # bump to re-send a changed value
}

# The same idea for the lab's root module (terraform/environments/hyperv), not
# applied there so the Terraform guide stands alone without Vault:
#
#   ephemeral "vault_kv_secret_v2" "hyperv" {
#     mount = "secret"
#     name  = "homelab/hyperv"
#   }
#   provider "hyperv" {
#     user     = ephemeral.vault_kv_secret_v2.hyperv.data["user"]
#     password = ephemeral.vault_kv_secret_v2.hyperv.data["password"]
#     ...
#   }
#
# Module 10 of the guide takes the environment-variable route instead
# (TF_VAR_hyperv_password from `vault kv get`), which needs no code change.
