#!/usr/bin/env bash
# Smoke test for everything under vault/ with NO lab: a throwaway dev server on
# 127.0.0.1:18200 loads the three policies, both SSH roles, builds the PKI the
# guide builds (root, intermediate, role homelab) and runs Vault Agent once with
# the real agent.hcl + cert.tpl, then checks the rendered certificate chains to
# the root. Also: bash -n on the scripts, jq on the JSON role files, terraform
# validate on the example. Needs: vault, jq, openssl (terraform optional).
# -dev-no-store-token: a dev server otherwise overwrites ~/.vault-token, logging
# you out of the lab Vault.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fail=0
tmp=$(mktemp -d)
devpid=
cleanup() { [ -n "$devpid" ] && kill "$devpid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
step() { printf '\n== %s\n' "$*"; }
for t in vault jq openssl; do command -v "$t" >/dev/null || { echo "FAIL: $t not installed"; exit 1; }; done

step "files exist and parse"
for f in vault/scripts/issue-server-cert.sh ansible/roles/vault_server/files/vault-snapshot.sh; do
  if [ -f "$f" ] && bash -n "$f"; then echo "ok   bash -n $f"; else echo "FAIL: $f missing or does not parse"; fail=1; fi
done
for f in vault/ssh/client-role.json vault/ssh/host-role.json; do
  if jq -e . "$f" >/dev/null 2>&1; then echo "ok   json $f"; else echo "FAIL: $f missing or not JSON"; fail=1; fi
done
for f in vault/policies/admin.hcl vault/policies/automation.hcl vault/policies/backup.hcl \
         vault/agent/agent.hcl vault/agent/cert.tpl \
         ansible/roles/vault_server/files/vault-snapshot.service ansible/roles/vault_server/files/vault-snapshot.timer \
         ansible/roles/vault_server/files/logrotate-vault ansible/roles/vault_server/templates/vault.hcl.j2; do
  if [ -f "$f" ]; then echo "ok   $f"; else echo "FAIL: $f missing"; fail=1; fi
done

step "terraform/examples/vault-secrets: init + validate"
if ! command -v terraform >/dev/null; then
  echo "(terraform not installed: skipped)"
elif (cd terraform/examples/vault-secrets && terraform init -backend=false -input=false -no-color >"$tmp/tfinit.log" 2>&1 && terraform validate -no-color >"$tmp/tfval.log" 2>&1); then
  echo "ok   $(grep -E 'Installing hashicorp/vault' "$tmp/tfinit.log" | head -1 | sed 's/^- //')"
else
  tail -8 "$tmp/tfinit.log" "$tmp/tfval.log" 2>/dev/null; echo "FAIL: terraform validate"; fail=1
fi

[ "$fail" -eq 0 ] || { echo "FAIL: vault static checks"; exit 1; }   # no point starting a dev server

step "dev server: policies, SSH roles, PKI, AppRole, agent"
export VAULT_ADDR=http://127.0.0.1:18200 VAULT_TOKEN=root
unset VAULT_CACERT VAULT_SKIP_VERIFY
vault server -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:18200 -dev-no-store-token >"$tmp/dev.log" 2>&1 &
devpid=$!
for _ in $(seq 20); do vault status >/dev/null 2>&1 && break; sleep 0.5; done
vault status >/dev/null 2>&1 || { cat "$tmp/dev.log"; echo "FAIL: dev server did not start"; exit 1; }
cd vault || exit 2

for p in admin automation backup; do
  if vault policy write "$p" "policies/$p.hcl" >/dev/null 2>"$tmp/err"; then echo "ok   policy $p"; else cat "$tmp/err"; echo "FAIL: policy $p"; fail=1; fi
done
if vault secrets enable -path=ssh-client-signer ssh >/dev/null && vault write ssh-client-signer/roles/default @ssh/client-role.json >/dev/null 2>"$tmp/err"; then
  echo "ok   ssh-client-signer/roles/default"; else cat "$tmp/err"; echo "FAIL: client role"; fail=1; fi
if vault secrets enable -path=ssh-host-signer ssh >/dev/null && vault write ssh-host-signer/roles/hostrole @ssh/host-role.json >/dev/null 2>"$tmp/err"; then
  echo "ok   ssh-host-signer/roles/hostrole"; else cat "$tmp/err"; echo "FAIL: host role"; fail=1; fi

# The PKI exactly as Module 05 builds it
vault secrets enable pki >/dev/null && vault secrets tune -max-lease-ttl=87600h pki >/dev/null
vault write -field=certificate pki/root/generate/internal common_name="Lab Root CA" issuer_name=root-test ttl=87600h >"$tmp/root_ca.crt" 2>/dev/null   # AIA warning: the guide sets config/urls next
vault secrets enable -path=pki_int pki >/dev/null && vault secrets tune -max-lease-ttl=43800h pki_int >/dev/null
vault write -format=json pki_int/intermediate/generate/internal common_name="Lab Intermediate CA" | jq -r .data.csr >"$tmp/int.csr"
vault write -format=json pki/root/sign-intermediate csr=@"$tmp/int.csr" format=pem_bundle ttl=43800h | jq -r .data.certificate >"$tmp/int.crt"
vault write pki_int/intermediate/set-signed certificate=@"$tmp/int.crt" >/dev/null
if vault write pki_int/roles/homelab allowed_domains=lab.internal allow_subdomains=true allow_ip_sans=true max_ttl=8760h ttl=720h >/dev/null; then
  echo "ok   pki: root, intermediate, role homelab"; else echo "FAIL: pki"; fail=1; fi

# AppRole with the automation policy, then the agent with the committed config.
# agent.hcl's paths are relative to vault/; the temp dir mirrors that layout.
vault auth enable approle >/dev/null
vault write auth/approle/role/automation token_policies=automation token_ttl=1h token_max_ttl=4h secret_id_ttl=720h >/dev/null
mkdir -p "$tmp/run/local/agent" && cp -r agent "$tmp/run/agent"
vault read -field=role_id auth/approle/role/automation/role-id >"$tmp/run/local/agent/role-id"
vault write -f -field=secret_id auth/approle/role/automation/secret-id >"$tmp/run/local/agent/secret-id"
(cd "$tmp/run" && timeout 30 vault agent -config=agent/agent.hcl -exit-after-auth >"$tmp/agent.log" 2>&1); rc=$?
grep -E 'authentication successful|rendered|error' "$tmp/agent.log" | sed 's/^/     /' | head -6
if [ -s "$tmp/run/local/agent/tls.crt" ] && [ -s "$tmp/run/local/agent/tls.key" ]; then
  echo "ok   agent rendered local/agent/tls.crt and tls.key (exit $rc)"
else
  tail -20 "$tmp/agent.log"; echo "FAIL: agent did not render the certificate (exit $rc)"; fail=1
fi
if openssl x509 -in "$tmp/run/local/agent/tls.crt" -out "$tmp/leaf.crt" 2>/dev/null \
   && openssl verify -CAfile "$tmp/root_ca.crt" -untrusted "$tmp/int.crt" "$tmp/leaf.crt" >/dev/null 2>"$tmp/err"; then
  echo "ok   $(openssl x509 -in "$tmp/leaf.crt" -noout -subject) chains to the root"
else
  cat "$tmp/err"; echo "FAIL: rendered certificate does not verify against the root"; fail=1
fi

[ "$fail" -eq 0 ] && echo "vault-static: PASS" || echo "vault-static: FAIL"
exit $fail
