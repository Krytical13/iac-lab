#!/usr/bin/env bash
# The lab is up: three VMs report addresses on the LAN, answer SSH as sysadmin with their own
# names, Ansible pings them through the inventory Terraform wrote, and a second plan is a no-op.
. "$(dirname "$0")/host-lib.sh"   # LAN_PREFIX; also cd to the repo root
ENV=terraform/environments/hyperv
INV=ansible/inventories/hyperv-lab/hosts.yml
SSH_OPTS=(-i "$HOME/.ssh/lab_key" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
rc=0
ok()   { echo "ok   $*"; }
fail() { echo "FAIL $*"; rc=1; }

ips_json=$(terraform -chdir="$ENV" output -json vm_ips 2>/dev/null) || ips_json='{}'
pairs=$(printf '%s' "$ips_json" | python3 -c 'import json,sys
d=json.load(sys.stdin); print(" ".join(f"{k}={v}" for k,v in sorted(d.items()) if v))')
count=$(echo "$pairs" | wc -w)
[ "$count" = 3 ] && ok "vm_ips reports 3 addresses" || fail "vm_ips reports $count address(es): $ips_json"
for pair in $pairs; do
  name=${pair%%=*}; ip=${pair#*=}
  case "$ip" in "$LAN_PREFIX"*) ok "$name is at $ip (on the LAN)" ;; *) fail "$name is at $ip (expected $LAN_PREFIX*)" ;; esac
  got=$(ssh "${SSH_OPTS[@]}" "sysadmin@$ip" hostname 2>/dev/null)
  [ "$got" = "$name" ] && ok "ssh sysadmin@$ip hostname → $got" || fail "ssh sysadmin@$ip hostname → '$got'"
done
if [ -r "$INV" ]; then
  pong=$(ANSIBLE_HOST_KEY_CHECKING=False ansible -i "$INV" linux -m ping 2>/dev/null | grep -c '"ping": "pong"')
  [ "$pong" = 3 ] && ok "ansible -m ping: 3 pong" || fail "ansible -m ping: $pong pong"
else
  fail "$INV missing (Terraform writes it on apply)"
fi
terraform -chdir="$ENV" plan -no-color -input=false -detailed-exitcode >/dev/null 2>&1; code=$?
[ "$code" = 0 ] && ok "second terraform plan: No changes" || fail "second terraform plan exit $code (2 = changes pending, 1 = error)"
[ "$rc" -eq 0 ] && echo "lab-up: PASS" || echo "lab-up: FAIL"
exit "$rc"
