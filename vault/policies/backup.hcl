# vault/policies/backup.hcl — the snapshot job's token (Vault guide, Module 09).
# One capability on one path: a leaked backup token can copy the encrypted
# snapshot (useless without the unseal keys) and nothing else.
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
