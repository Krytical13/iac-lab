#!/usr/bin/env bash
# Daily Raft snapshot, run by vault-snapshot.timer on the Vault server itself.
# Needs: /etc/vault.d/backup-token (a periodic token with the "backup" policy,
# created in Module 09 of the guide) and /opt/vault/tls/ca.crt (the lab root CA,
# installed by vault/scripts/issue-server-cert.sh in Module 05).
set -euo pipefail

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_CACERT=/opt/vault/tls/ca.crt
VAULT_TOKEN=$(cat /etc/vault.d/backup-token)
export VAULT_TOKEN

# A periodic token lives only as long as it keeps being renewed: renew first, so
# a job that runs every day keeps a 30-day token alive indefinitely, and a lab
# parked for longer than the period fails here with a clear "token expired".
vault token renew >/dev/null

dest=/opt/vault/backups/vault-$(date +%Y%m%d-%H%M).snap
vault operator raft snapshot save "$dest"
echo "snapshot written: $dest ($(stat -c %s "$dest") bytes)"

# Keep a month. Snapshots are encrypted with the cluster's keys: restoring one
# needs the unseal keys, so copying them off the box is safe.
find /opt/vault/backups -name '*.snap' -mtime +30 -delete
