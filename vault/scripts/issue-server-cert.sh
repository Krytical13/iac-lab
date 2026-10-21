#!/usr/bin/env bash
# Give the Vault server a certificate from its own PKI (Vault guide, Module 05).
#   usage: scripts/issue-server-cert.sh <vault-server-ip> [ssh-user]
# Run from the vault/ directory as the Vault admin (VAULT_ADDR set, logged in),
# after Module 05 created pki_int and the role "homelab", with local/root_ca.crt
# present. Issues vault-lab-01.lab.internal with the server's IP and 127.0.0.1 as
# IP SANs, installs certificate+chain, key and the root CA under /opt/vault/tls/
# on the server, and restarts Vault — which comes back SEALED. Unseal it after.
set -euo pipefail

ip=${1:?usage: $0 <vault-server-ip> [ssh-user]}
user=${2:-sysadmin}
name=${VAULT_SERVER_NAME:-vault-lab-01.lab.internal}
[ -r local/root_ca.crt ] || { echo "local/root_ca.crt not found: run from vault/ after creating the root CA"; exit 1; }

mkdir -p local
vault write -format=json pki_int/issue/homelab \
  common_name="$name" ip_sans="127.0.0.1,$ip" ttl=8760h >local/vault-server.json
jq -r '.data.certificate, .data.ca_chain[]' local/vault-server.json >local/vault-server.crt
jq -r '.data.private_key' local/vault-server.json >local/vault-server.key
chmod 600 local/vault-server.key local/vault-server.json
echo "issued: $(openssl x509 -in local/vault-server.crt -noout -subject -enddate | tr '\n' ' ')"

ssh_opts=(-i "$HOME/.ssh/lab_key" -o BatchMode=yes -o StrictHostKeyChecking=no -o LogLevel=ERROR)
install_remote() { # install_remote <local file> <remote path> <mode>
  ssh "${ssh_opts[@]}" "$user@$ip" "sudo install -o vault -g vault -m $3 /dev/stdin $2" <"$1"
}
install_remote local/vault-server.crt /opt/vault/tls/tls.crt 0644
install_remote local/vault-server.key /opt/vault/tls/tls.key 0600
install_remote local/root_ca.crt      /opt/vault/tls/ca.crt  0644
ssh "${ssh_opts[@]}" "$user@$ip" "sudo systemctl restart vault"
echo "installed under /opt/vault/tls/ and Vault restarted on $ip."
echo "Vault is now SEALED: unset VAULT_SKIP_VERIFY, export VAULT_CACERT=\$PWD/local/root_ca.crt, then vault operator unseal (twice)."
