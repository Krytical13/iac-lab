#!/usr/bin/env bash
# Static checks on the Ansible project, run from anywhere:
#   1. collections and Galaxy roles from requirements.yml install (idempotent)
#   2. the lab inventory directory parses with no warning (a stray file in an
#      inventory directory is read as a second inventory source)
#   3. site.yml passes --syntax-check
#   4. ansible-lint is clean (profile from ansible/.ansible-lint)
# Needs ansible-core and ansible-lint (pipx install ansible-lint). When the
# Terraform-written hosts.yml is absent (CI, a fresh fork) the example file
# stands in for it.
set -uo pipefail
cd "$(dirname "$0")/../ansible" || exit 2
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step() { printf '\n== %s\n' "$*"; }

# ansible.cfg names .vault_pass; ansible-core 2.20+ refuses to run anything when
# that file is missing. The lab password is public, so a stand-in is harmless.
[ -f .vault_pass ] || { echo labpassword > .vault_pass; echo "(created .vault_pass with the lab password)"; }

step "ansible-galaxy install -r requirements.yml"
if ! ansible-galaxy install -r requirements.yml >"$tmp/galaxy.log" 2>&1; then
  cat "$tmp/galaxy.log"; echo "FAIL: requirements did not install"; fail=1
else
  grep -E 'was installed successfully|Nothing to do|already installed|Skipping' "$tmp/galaxy.log" | head -5
fi

inv=inventories/hyperv-lab
if [ ! -f "$inv/hosts.yml" ]; then
  cp -r "$inv/." "$tmp/inv" && cp "$tmp/inv/hosts.yml.example" "$tmp/inv/hosts.yml"
  inv="$tmp/inv"
  echo "(no hosts.yml: using hosts.yml.example as the inventory)"
fi

step "ansible-inventory --graph"
ansible-inventory -i "$inv" --graph >"$tmp/graph.txt" 2>&1
cat "$tmp/graph.txt"
grep -q '@linux:' "$tmp/graph.txt" || { echo "FAIL: no linux group in the inventory"; fail=1; }
grep -q 'WARNING' "$tmp/graph.txt" && { echo "FAIL: the inventory directory produced a warning"; fail=1; }

step "ansible-playbook site.yml --syntax-check"
ansible-playbook -i "$inv" site.yml --syntax-check 2>&1 | tail -3 || true
ansible-playbook -i "$inv" site.yml --syntax-check >/dev/null 2>&1 || { echo "FAIL: syntax-check"; fail=1; }

step "ansible-lint"
if ! command -v ansible-lint >/dev/null; then
  echo "FAIL: ansible-lint not installed (pipx install ansible-lint)"; fail=1
elif ! ansible-lint >"$tmp/lint.log" 2>&1; then
  tail -25 "$tmp/lint.log"; echo "FAIL: ansible-lint"; fail=1
else
  tail -2 "$tmp/lint.log"
fi

[ "$fail" -eq 0 ] && echo "PASS: ansible static checks" || echo "FAIL: ansible static checks"
exit $fail
