#!/usr/bin/env bash
# End-to-end check of the Vault guide against the running lab, in guide order.
# Needs: the lab up, Modules 01–09 done, snmpwalk, VAULT_ADDR, VAULT_CACERT=vault/local/root_ca.crt
# (or run from the repo with that file present), and the userpass admin's token in
# ~/.vault-token (vault login -method=userpass username=labadmin) or VAULT_TOKEN.
# Never uses root: every call must work under the admin policy.
# Checks, stopping at the first failure:
#   1. vault status: unsealed; the token's policies include admin, not root
#   2. KV: secret/homelab/snmpd holds the community string the VMs' snmpd answer to (whatever it is now)
#   3. policies admin/automation/backup exist; AppRole login with vault/local/agent/{role-id,secret-id}
#   4. SSH user certs: a fresh key is refused, then accepted on all three VMs once signed
#   5. SSH host certs: a known_hosts with only the @cert-authority line connects without prompting
#   6. PKI: the API answers over TLS with the lab root as the only trust; a new cert chains to it
#   7. audit log receives entries; a Raft snapshot can be taken
#   8. the Ansible lookup reads the community string through hvac
#   9. base.yml is still changed=0 on all three, and the certificate login still works after it
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
die() { echo "FAIL: $*"; echo "vault-lab: FAIL"; exit 1; }
ok() { echo "ok   $*"; }
# A leftover VAULT_SKIP_VERIFY=true (Module 01) would make every check below pass without
# verifying the server; this test is about the lab root CA being the only trust.
unset VAULT_SKIP_VERIFY
export VAULT_CACERT=${VAULT_CACERT:-$PWD/vault/local/root_ca.crt}
[ -r "$VAULT_CACERT" ] || die "no CA at $VAULT_CACERT (Module 05 writes vault/local/root_ca.crt)"
[ -n "${VAULT_ADDR:-}" ] || die "VAULT_ADDR is not set"
vault_ip=$(echo "$VAULT_ADDR" | sed -E 's#https?://([^:/]+).*#\1#')
ip_of() { (cd ansible && ansible-inventory --host "$1" | jq -r .ansible_host); }   # from ansible/, so ansible.cfg applies
hosts="ubuntu-lab-01 rocky-lab-01 vault-lab-01"
sshq() { ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }

# 1. unsealed, and we are the named admin
vault status >"$tmp/status" 2>&1 || die "vault status (exit $?): $(head -1 "$tmp/status")"
grep -q '^Sealed *false' "$tmp/status" || die "Vault is sealed"
pols=$(vault token lookup -format=json | jq -r '.data.policies | join(",")')
case "$pols" in *admin*) ;; *) die "token policies are [$pols], expected the admin policy" ;; esac
case "$pols" in *root*) die "token is root; the guide works as labadmin from Module 03 on" ;; esac
ok "vault status unsealed; token policies [$pols]"

# 2. KV: the value in Vault is the one the hosts use (Module 10 rotates it; the test must not care which)
c=$(vault kv get -field=community secret/homelab/snmpd 2>&1) || die "kv get secret/homelab/snmpd: $c"
[ -n "$c" ] || die "secret/homelab/snmpd has an empty community"
got=$(snmpwalk -v2c -c "$c" -t 3 -r 1 "$(ip_of ubuntu-lab-01)" 1.3.6.1.2.1.1.5 2>&1 | head -1)
case "$got" in *"STRING: ubuntu-lab-01"*) ok "kv get secret/homelab/snmpd -> community=$c, and ubuntu-lab-01's snmpd answers to it" ;;
  *) die "snmpd on ubuntu-lab-01 does not answer to the community in Vault ('$c'): $got" ;; esac

# 3. policies and AppRole
for p in admin automation backup; do vault policy read "$p" >/dev/null 2>&1 || die "policy $p missing"; done
[ -r vault/local/agent/role-id ] && [ -r vault/local/agent/secret-id ] || die "vault/local/agent/{role-id,secret-id} missing (Module 03)"
atok=$(vault write -field=token auth/approle/login role_id="$(cat vault/local/agent/role-id)" secret_id="$(cat vault/local/agent/secret-id)" 2>&1) || die "approle login: $atok"
apols=$(VAULT_TOKEN=$atok vault token lookup -format=json | jq -r '.data.policies | join(",")')
case "$apols" in *automation*) ok "policies admin/automation/backup exist; AppRole login -> policies [$apols]" ;; *) die "AppRole token policies [$apols]" ;; esac

# 4. user certificates: refused unsigned, accepted signed, on every VM
ssh-keygen -q -t ed25519 -N '' -f "$tmp/key" || die ssh-keygen
u=$(ip_of ubuntu-lab-01)
if sshq -i "$tmp/key" -o IdentitiesOnly=yes "sysadmin@$u" true 2>/dev/null; then die "an unsigned fresh key was accepted by $u (the lab key must not be on the test key)"; fi
vault write -field=signed_key ssh-client-signer/sign/default public_key=@"$tmp/key.pub" >"$tmp/key-cert.pub" 2>"$tmp/err" || die "sign: $(cat "$tmp/err")"
for h in $hosts; do
  got=$(sshq -i "$tmp/key" -o IdentitiesOnly=yes "sysadmin@$(ip_of "$h")" hostname 2>&1) || die "certificate login to $h: $got"
  [ "$got" = "$h" ] || die "certificate login to $h returned '$got'"
done
ok "fresh key refused unsigned, accepted with a Vault certificate on 3 hosts"

# 5. host certificates: trust only the host CA, strict checking, no prompt
hostca=$(vault read -field=public_key ssh-host-signer/config/ca 2>&1) || die "host CA: $hostca"
echo "@cert-authority * $hostca" >"$tmp/known_hosts"
for h in $hosts; do
  got=$(ssh -i "$tmp/key" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$tmp/known_hosts" -o LogLevel=ERROR "sysadmin@$(ip_of "$h")" hostname 2>&1) \
    || die "host certificate for $h not accepted: $got"
done
ok "host certificates accepted with @cert-authority as the only known_hosts entry (3 hosts)"

# 6. TLS and PKI
code=$(curl -s -m 5 --cacert "$VAULT_CACERT" -o "$tmp/health" -w '%{http_code}' "https://$vault_ip:8200/v1/sys/health") || die "curl health over TLS with the lab root"
[ "$code" = 200 ] && [ "$(jq -r .sealed "$tmp/health")" = false ] || die "health returned $code: $(cat "$tmp/health")"
vault write -format=json pki_int/issue/homelab common_name=check.lab.internal ttl=1h >"$tmp/cert.json" 2>"$tmp/err" || die "pki issue: $(cat "$tmp/err")"
jq -r .data.certificate "$tmp/cert.json" >"$tmp/leaf.crt"; jq -r '.data.ca_chain[]' "$tmp/cert.json" >"$tmp/chain.crt"
openssl verify -CAfile "$VAULT_CACERT" -untrusted "$tmp/chain.crt" "$tmp/leaf.crt" >/dev/null 2>&1 || die "issued certificate does not chain to the lab root"
ok "API verifies with the lab root (health 200, sealed=false); new certificate chains to it"

# 7. audit and snapshot
vault kv get secret/homelab/snmpd >/dev/null
t=$(sshq -i "$HOME/.ssh/lab_key" "sysadmin@$vault_ip" 'sudo tail -1 /var/log/vault/audit.log' 2>/dev/null | jq -r .type 2>/dev/null)
[ "$t" = response ] || die "audit.log last entry type '$t' (expected response)"
vault operator raft snapshot save "$tmp/snap" 2>"$tmp/err" || die "raft snapshot: $(cat "$tmp/err")"
[ -s "$tmp/snap" ] || die "snapshot is empty"
ok "audit log records requests; raft snapshot $(stat -c %s "$tmp/snap") bytes"

# 8. Ansible lookup through hvac
got=$(cd ansible && ansible vault-lab-01 -m ansible.builtin.debug -a "msg={{ lookup('community.hashi_vault.vault_kv2_get', 'homelab/snmpd', engine_mount_point='secret').secret.community }}" 2>&1 | grep -o '"msg": "[^"]*"' | cut -d'"' -f4)
[ "$got" = "$c" ] || die "ansible lookup returned '$got' (Vault holds '$c')"
ok "community.hashi_vault lookup -> $got"

# 9. the baseline is still idempotent with the CA trust in place
(cd ansible && ansible-playbook playbooks/base.yml >"$tmp/base.log" 2>&1) || { tail -15 "$tmp/base.log"; die "base.yml"; }
recap=$(sed -n '/PLAY RECAP/,$p' "$tmp/base.log"); echo "$recap" | grep lab-01
[ "$(echo "$recap" | grep -c 'changed=0 ')" -eq 3 ] || die "base.yml is not changed=0 on all three"
got=$(sshq -i "$tmp/key" -o IdentitiesOnly=yes "sysadmin@$u" hostname 2>&1) || die "certificate login after base.yml: $got"
ok "base.yml changed=0 ×3; certificate login still works"

echo "vault-lab: PASS"
